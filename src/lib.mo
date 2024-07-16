/// A module which implements auction functionality for various trading pairs against "trusted" fungible token
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Array "mo:base/Array";
import AssocList "mo:base/AssocList";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import List "mo:base/List";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Option "mo:base/Option";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import R "mo:base/Result";
import RBTree "mo:base/RBTree";

import Vec "mo:vector";

import { calculateDeal } "./calculate-deal";

module {

  public type AssetId = Nat;
  public type OrderId = Nat;

  public type StableDataV1 = {
    counters : (sessions : Nat, orders : Nat);
    assets : Vec.Vector<StableAssetInfo>;
    users : RBTree.Tree<Principal, UserInfo>;
    history : List.List<PriceHistoryItem>;
    stats : {
      usersAmount : Nat;
      accountsAmount : Nat;
      assets : Vec.Vector<{ bidsAmount : Nat; totalBidVolume : Nat; asksAmount : Nat; totalAskVolume : Nat; lastProcessingInstructions : Nat }>;
    };
  };

  public func defaultStableDataV1() : StableDataV1 = {
    counters = (0, 0);
    assets = Vec.new();
    users = #leaf;
    history = null;
    stats = {
      usersAmount = 0;
      accountsAmount = 0;
      assets = Vec.new();
    };
  };

  public type Account = {
    // balance of user account
    var credit : Nat;
    // user's credit, placed as bid or ask
    var lockedCredit : Nat;
  };

  public type PriceHistoryItem = (timestamp : Nat64, sessionNumber : Nat, assetId : AssetId, volume : Nat, price : Float);
  public type TransactionHistoryItem = (timestamp : Nat64, sessionNumber : Nat, kind : { #ask; #bid }, assetId : AssetId, volume : Nat, price : Float);

  public type Order = {
    user : Principal;
    userInfoRef : UserInfo;
    assetId : AssetId;
    price : Float;
    var volume : Nat;
  };

  public type SharedOrder = {
    assetId : AssetId;
    price : Float;
    volume : Nat;
  };

  public type UserInfo = {
    var currentAsks : AssocList.AssocList<OrderId, Order>;
    var currentBids : AssocList.AssocList<OrderId, Order>;
    var credits : AssocList.AssocList<AssetId, Account>;
    var history : List.List<TransactionHistoryItem>;
  };

  public type StableAssetInfo = {
    asks : AssocList.AssocList<OrderId, Order>;
    bids : AssocList.AssocList<OrderId, Order>;
    lastSwapRate : Float;
  };

  public type AssetInfo = {
    var asks : AssocList.AssocList<OrderId, Order>;
    var bids : AssocList.AssocList<OrderId, Order>;
    var lastSwapRate : Float;
  };

  public type CancellationAction = {
    #all : ?[AssetId];
    #orders : [{ #ask : OrderId; #bid : OrderId }];
  };

  public type PlaceOrderAction = {
    #ask : (assetId : AssetId, volume : Nat, price : Float);
    #bid : (assetId : AssetId, volume : Nat, price : Float);
  };

  type InternalCancelOrderError = { #UnknownOrder };
  type InternalPlaceOrderError = {
    #ConflictingOrder : ({ #ask; #bid }, ?OrderId);
    #NoCredit;
    #TooLowOrder;
    #UnknownAsset;
  };

  public type OrderManagementError = {
    #UnknownPrincipal;
    #cancellation : { index : Nat; error : InternalCancelOrderError };
    #placement : { index : Nat; error : InternalPlaceOrderError };
  };

  public type CancelOrderError = InternalCancelOrderError or {
    #UnknownPrincipal;
  };
  public type PlaceOrderError = InternalPlaceOrderError or {
    #UnknownPrincipal;
  };
  public type ReplaceOrderError = CancelOrderError or PlaceOrderError;

  public func getTotalPrice(volume : Nat, unitPrice : Float) : Nat = Int.abs(Float.toInt(Float.ceil(unitPrice * Float.fromInt(volume))));

  // internal usage only
  type OrderCtx = {
    assetList : (assetInfo : AssetInfo) -> AssocList.AssocList<OrderId, Order>;
    assetListSet : (assetInfo : AssetInfo, list : AssocList.AssocList<OrderId, Order>) -> ();

    kind : { #ask; #bid };
    userList : (userInfo : UserInfo) -> AssocList.AssocList<OrderId, Order>;
    userListSet : (userInfo : UserInfo, list : AssocList.AssocList<OrderId, Order>) -> ();

    oppositeKind : { #ask; #bid };
    userOppositeList : (userInfo : UserInfo) -> AssocList.AssocList<OrderId, Order>;
    oppositeOrderConflictCriteria : (orderPrice : Float, oppositeOrderPrice : Float) -> Bool;

    chargeToken : (orderAssetId : AssetId) -> AssetId;
    chargeAmount : (volume : Nat, price : Float) -> Nat;
    priorityComparator : (order : Order, newOrder : Order) -> Bool;
    lowOrderSign : (orderAssetId : AssetId, orderAssetInfo : AssetInfo, volume : Nat, price : Float) -> Bool;

    amountStat : (assetId : AssetId) -> {
      add : (n : Nat) -> ();
      sub : (n : Nat) -> ();
    };
    volumeStat : (assetId : AssetId) -> {
      add : (n : Nat) -> ();
      sub : (n : Nat) -> ();
    };
  };

  public class Auction(
    trustedAssetId : AssetId,
    settings : {
      minimumOrder : Nat;
      minAskVolume : (AssetId, AssetInfo) -> Int;
      performanceCounter : Nat32 -> Nat64;
    },
  ) {

    // a counter of conducted auction sessions
    public var sessionsCounter = 0;
    // a counter of ever added order
    public var ordersCounter = 0;
    // asset info, index == assetId
    public var assets : Vec.Vector<AssetInfo> = Vec.new();
    // user info
    public let users : RBTree.RBTree<Principal, UserInfo> = RBTree.RBTree<Principal, UserInfo>(Principal.compare);
    // asset history
    public var history : List.List<PriceHistoryItem> = null;
    // stats
    public var stats : {
      var usersAmount : Nat;
      var accountsAmount : Nat;
      assets : Vec.Vector<{ var bidsAmount : Nat; var totalBidVolume : Nat; var asksAmount : Nat; var totalAskVolume : Nat; var lastProcessingInstructions : Nat }>;
    } = {
      var usersAmount = 0;
      var accountsAmount = 0;
      assets = Vec.new();
    };

    public func initUser(p : Principal) : UserInfo {
      let data : UserInfo = {
        var currentAsks = null;
        var currentBids = null;
        var credits = null;
        var history = null;
      };
      let oldValue = users.replace(p, data);
      switch (oldValue) {
        case (?v) Prim.trap("Prevented user data overwrite");
        case (_) {};
      };
      stats.usersAmount += 1;
      data;
    };

    public func registerAssets(n : Nat) {
      var assetsVecSize = Vec.size(assets);
      let newAmount = assetsVecSize + n;
      while (assetsVecSize < newAmount) {
        (
          {
            var asks = List.nil();
            var askCounter = 0;
            var bids = List.nil();
            var bidCounter = 0;
            var lastSwapRate = 0;
          } : AssetInfo
        )
        |> Vec.add(assets, _);
        ({
          var asksAmount = 0;
          var bidsAmount = 0;
          var lastProcessingInstructions = 0;
          var totalAskVolume = 0;
          var totalBidVolume = 0;
        })
        |> Vec.add(stats.assets, _);
        assetsVecSize += 1;
      };
    };

    public func queryCredit(p : Principal, assetId : AssetId) : Nat = users.get(p)
    |> Option.chain<UserInfo, Account>(_, func(info) = AssocList.find(info.credits, assetId, Nat.equal))
    |> Option.map<Account, Nat>(_, func(acc) = acc.credit - acc.lockedCredit)
    |> Option.get(_, 0);

    public func queryCredits(p : Principal) : [(AssetId, Nat)] = switch (users.get(p)) {
      case (null) [];
      case (?ui) {
        let length = List.size(ui.credits);
        var list = ui.credits;
        Array.tabulate<(AssetId, Nat)>(
          length,
          func(i) {
            let popped = List.pop(list);
            list := popped.1;
            switch (popped.0) {
              case null { loop { assert false } };
              case (?x) (x.0, x.1.credit - x.1.lockedCredit);
            };
          },
        );
      };
    };

    private func queryOrders_(p : Principal, f : (ui : UserInfo) -> AssocList.AssocList<OrderId, Order>) : [(OrderId, SharedOrder)] = switch (users.get(p)) {
      case (null) [];
      case (?ui) {
        var list = f(ui);
        let length = List.size(list);
        Array.tabulate<(OrderId, SharedOrder)>(
          length,
          func(i) {
            let popped = List.pop(list);
            list := popped.1;
            switch (popped.0) {
              case null { loop { assert false } };
              case (?(orderId, order)) (orderId, { order with volume = order.volume });
            };
          },
        );
      };
    };

    private func queryOrder_(p : Principal, ctx : OrderCtx, orderId : OrderId) : ?SharedOrder {
      switch (users.get(p)) {
        case (null) null;
        case (?ui) {
          for ((oid, order) in List.toIter(ctx.userList(ui))) {
            if (oid == orderId) {
              return ?{ order with volume = order.volume };
            };
          };
          null;
        };
      };
    };

    public func queryAssetAsks(p : Principal, assetId : AssetId) : [(OrderId, SharedOrder)] = queryOrders_(
      p,
      func(info) = info.currentAsks |> List.filter<(OrderId, Order)>(_, func(_, o) = o.assetId == assetId),
    );
    public func queryAssetBids(p : Principal, assetId : AssetId) : [(OrderId, SharedOrder)] = queryOrders_(
      p,
      func(info) = info.currentBids |> List.filter<(OrderId, Order)>(_, func(_, o) = o.assetId == assetId),
    );

    public func queryAsks(p : Principal) : [(OrderId, SharedOrder)] = queryOrders_(p, func(info) = info.currentAsks);
    public func queryBids(p : Principal) : [(OrderId, SharedOrder)] = queryOrders_(p, func(info) = info.currentBids);

    public func queryAsk(p : Principal, orderId : OrderId) : ?SharedOrder = queryOrder_(p, askCtx, orderId);
    public func queryBid(p : Principal, orderId : OrderId) : ?SharedOrder = queryOrder_(p, bidCtx, orderId);

    private func sliceList<T>(list : List.List<T>, limit : Nat, skip : Nat) : [T] {
      var tail = list;
      var i = 0;
      while (i < skip) {
        let ?(_, next) = tail else return [];
        tail := next;
        i += 1;
      };
      let ret : Vec.Vector<T> = Vec.new();
      i := 0;
      label l while (i < limit) {
        let ?(item, next) = tail else break l;
        Vec.add(ret, item);
        tail := next;
        i += 1;
      };
      Vec.toArray(ret);
    };

    private func sliceListWithFilter<T>(list : List.List<T>, f : (item : T) -> Bool, limit : Nat, skip : Nat) : [T] {
      var tail = list;
      var i = 0;
      while (i < skip) {
        let ?(item, next) = tail else return [];
        tail := next;
        if (f(item)) {
          i += 1;
        };
      };
      let ret : Vec.Vector<T> = Vec.new();
      i := 0;
      label l while (i < limit) {
        let ?(item, next) = tail else break l;
        if (f(item)) {
          Vec.add(ret, item);
          i += 1;
        };
        tail := next;
      };
      Vec.toArray(ret);
    };

    public func queryTransactionHistory(p : Principal, assetId : ?AssetId, limit : Nat, skip : Nat) : [TransactionHistoryItem] {
      let ?userInfo = users.get(p) else return [];
      switch (assetId) {
        case (?aid) sliceListWithFilter(userInfo.history, func(item : TransactionHistoryItem) : Bool = item.3 == aid, limit, skip);
        case (null) sliceList(userInfo.history, limit, skip);
      };
    };

    public func queryPriceHistory(assetId : ?AssetId, limit : Nat, skip : Nat) : [PriceHistoryItem] {
      switch (assetId) {
        case (?aid) sliceListWithFilter(history, func(item : PriceHistoryItem) : Bool = item.2 == aid, limit, skip);
        case (null) sliceList(history, limit, skip);
      };
    };

    public func appendCredit(p : Principal, assetId : AssetId, amount : Nat) : Nat {
      let userInfo = switch (users.get(p)) {
        case (?info) info;
        case (null) initUser(p);
      };
      switch (AssocList.find<AssetId, Account>(userInfo.credits, assetId, Nat.equal)) {
        case (?acc) {
          acc.credit += amount;
          acc.credit - acc.lockedCredit;
        };
        case (null) {
          { var credit = amount; var lockedCredit = 0 }
          |> AssocList.replace<AssetId, Account>(userInfo.credits, assetId, Nat.equal, ?_)
          |> (userInfo.credits := _.0);
          stats.accountsAmount += 1;
          amount;
        };
      };
    };

    public func setCredit(p : Principal, assetId : AssetId, credit : Nat) : Nat {
      let userInfo = switch (users.get(p)) {
        case (?info) info;
        case (null) initUser(p);
      };
      switch (AssocList.find<AssetId, Account>(userInfo.credits, assetId, Nat.equal)) {
        case (?acc) {
          acc.credit := credit;
          acc.credit - acc.lockedCredit;
        };
        case (null) {
          { var credit = credit; var lockedCredit = 0 }
          |> AssocList.replace<AssetId, Account>(userInfo.credits, assetId, Nat.equal, ?_)
          |> (userInfo.credits := _.0);
          stats.accountsAmount += 1;
          credit;
        };
      };
    };

    public func deductCredit(p : Principal, assetId : AssetId, amount : Nat) : R.Result<(Nat, rollback : () -> ()), { #NoCredit }> {
      let ?user = users.get(p) else return #err(#NoCredit);
      let ?creditAcc = AssocList.find(user.credits, assetId, Nat.equal) else return #err(#NoCredit);
      if (creditAcc.credit < amount + creditAcc.lockedCredit) return #err(#NoCredit);
      // charge credit
      creditAcc.credit -= amount;
      #ok(
        creditAcc.credit,
        func() = creditAcc.credit += amount,
      );
    };

    private func getUserTrustedAccount_(userInfo : UserInfo) : ?Account = AssocList.find<AssetId, Account>(userInfo.credits, trustedAssetId, Nat.equal);

    let askCtx : OrderCtx = {
      kind = #ask;
      assetList = func(assetInfo) = assetInfo.asks;
      assetListSet = func(assetInfo, list) { assetInfo.asks := list };
      userList = func(userInfo) = userInfo.currentAsks;
      userListSet = func(userInfo, list) { userInfo.currentAsks := list };

      oppositeKind = #bid;
      userOppositeList = func(userInfo) = userInfo.currentBids;
      oppositeOrderConflictCriteria = func(orderPrice, oppositeOrderPrice) = oppositeOrderPrice >= orderPrice;

      chargeToken = func(assetId) = assetId;
      chargeAmount = func(volume, _) = volume;
      priorityComparator = func(order, newOrder) = order.price > newOrder.price;
      lowOrderSign = func(assetId, assetInfo, volume, price) = volume == 0 or (price > 0 and volume < settings.minAskVolume(assetId, assetInfo));

      amountStat = func(assetId) = {
        add = func(n : Nat) {
          Vec.get(stats.assets, assetId).asksAmount += n;
        };
        sub = func(n : Nat) {
          Vec.get(stats.assets, assetId).asksAmount -= n;
        };
      };
      volumeStat = func(assetId) = {
        add = func(n : Nat) {
          Vec.get(stats.assets, assetId).totalAskVolume += n;
        };
        sub = func(n : Nat) {
          Vec.get(stats.assets, assetId).totalAskVolume -= n;
        };
      };
    };
    let bidCtx : OrderCtx = {
      kind = #bid;
      assetList = func(assetInfo) = assetInfo.bids;
      assetListSet = func(assetInfo, list) { assetInfo.bids := list };
      userList = func(userInfo) = userInfo.currentBids;
      userListSet = func(userInfo, list) { userInfo.currentBids := list };

      oppositeKind = #ask;
      userOppositeList = func(userInfo) = userInfo.currentAsks;
      oppositeOrderConflictCriteria = func(orderPrice, oppositeOrderPrice) = oppositeOrderPrice <= orderPrice;

      chargeToken = func(_) = trustedAssetId;
      chargeAmount = getTotalPrice;
      priorityComparator = func(order, newOrder) = order.price < newOrder.price;
      lowOrderSign = func(_, _, volume, price) = getTotalPrice(volume, price) < settings.minimumOrder;

      amountStat = func(assetId) = {
        add = func(n : Nat) {
          Vec.get(stats.assets, assetId).bidsAmount += n;
        };
        sub = func(n : Nat) {
          Vec.get(stats.assets, assetId).bidsAmount -= n;
        };
      };
      volumeStat = func(assetId) = {
        add = func(n : Nat) {
          Vec.get(stats.assets, assetId).totalBidVolume += n;
        };
        sub = func(n : Nat) {
          Vec.get(stats.assets, assetId).totalBidVolume -= n;
        };
      };
    };

    // order management functions
    private func placeOrderInternal(ctx : OrderCtx, userInfo : UserInfo, accountToCharge : Account, assetId : AssetId, assetInfo : AssetInfo, order : Order) : OrderId {
      let orderId = ordersCounter;
      ordersCounter += 1;
      // update user info
      AssocList.replace<OrderId, Order>(ctx.userList(userInfo), orderId, Nat.equal, ?order) |> ctx.userListSet(userInfo, _.0);
      accountToCharge.lockedCredit += ctx.chargeAmount(order.volume, order.price);
      // update asset info
      insertWithPriority<(OrderId, Order)>(
        ctx.assetList(assetInfo),
        (orderId, order),
        func(x) = ctx.priorityComparator(x.1, order),
      )
      |> ctx.assetListSet(assetInfo, _);
      // update stats
      ctx.amountStat(assetId).add(1);
      ctx.volumeStat(assetId).add(order.volume);
      orderId;
    };

    public func cancelOrderInternal(ctx : OrderCtx, userInfo : UserInfo, orderId : OrderId) : ?Order {
      AssocList.replace(ctx.userList(userInfo), orderId, Nat.equal, null)
      |> (
        switch (_) {
          case (_, null) null;
          case (map, ?existingOrder) {
            ctx.userListSet(userInfo, map);
            // return deposit to user
            let ?sourceAcc = AssocList.find<AssetId, Account>(userInfo.credits, ctx.chargeToken(existingOrder.assetId), Nat.equal) else Prim.trap("Can never happen");
            sourceAcc.lockedCredit -= ctx.chargeAmount(existingOrder.volume, existingOrder.price);
            // remove ask from asset data
            let assetInfo = Vec.get(assets, existingOrder.assetId);
            let (upd, deleted) = listFindOneAndDelete<(OrderId, Order)>(ctx.assetList(assetInfo), func(id, _) = id == orderId);
            assert deleted; // should always be true unless we have a bug with asset orders and user orders out of sync
            ctx.assetListSet(assetInfo, upd);
            ctx.amountStat(existingOrder.assetId).sub(1);
            ctx.volumeStat(existingOrder.assetId).sub(existingOrder.volume);
            ?existingOrder;
          };
        }
      );
    };

    // public shortcuts, optimized by skipping userInfo tree lookup and all validation checks
    public func placeAskInternal(userInfo : UserInfo, askSourceAcc : Account, assetId : AssetId, assetInfo : AssetInfo, order : Order) : OrderId {
      placeOrderInternal(askCtx, userInfo, askSourceAcc, assetId, assetInfo, order);
    };

    public func placeBidInternal(userInfo : UserInfo, trustedAcc : Account, assetId : AssetId, assetInfo : AssetInfo, order : Order) : OrderId {
      placeOrderInternal(bidCtx, userInfo, trustedAcc, assetId, assetInfo, order);
    };

    public func cancelAskInternal(userInfo : UserInfo, orderId : OrderId) : ?Order {
      cancelOrderInternal(askCtx, userInfo, orderId);
    };

    public func cancelBidInternal(userInfo : UserInfo, orderId : OrderId) : ?Order {
      cancelOrderInternal(bidCtx, userInfo, orderId);
    };

    // public interface
    public func manageOrders(
      p : Principal,
      cancellations : ?CancellationAction,
      placements : [PlaceOrderAction],
    ) : R.Result<[OrderId], OrderManagementError> {
      let ?userInfo = users.get(p) else return #err(#UnknownPrincipal);

      // temporary list of new balances for all affected user credit accounts
      var newBalances : AssocList.AssocList<AssetId, Nat> = null;
      // temporary lists of newly placed/cancelled orders
      type OrdersDelta = {
        var placed : List.List<(?OrderId, Order)>;
        var isOrderCancelled : (assetId : AssetId, orderId : OrderId) -> Bool;
      };
      var asksDelta : OrdersDelta = {
        var placed = null;
        var isOrderCancelled = func(_, _) = false;
      };
      var bidsDelta : OrdersDelta = {
        var placed = null;
        var isOrderCancelled = func(_, _) = false;
      };

      // array of functions which will write all changes to the state
      var cancellationCommitActions : List.List<() -> ()> = null;
      let placementCommitActions : [var () -> OrderId] = Array.init<() -> OrderId>(placements.size(), func() = 0);

      // validate and prepare cancellations

      // update temporary balances: add unlocked credits for each cancelled order
      func affectNewBalancesWithCancellation(ctx : OrderCtx, orderId : OrderId, order : Order) {
        let chargeToken = ctx.chargeToken(order.assetId);
        let ?chargeAcc = AssocList.find<AssetId, Account>(userInfo.credits, chargeToken, Nat.equal) else Prim.trap("Can never happen");
        let balance = switch (AssocList.find<AssetId, Nat>(newBalances, chargeToken, Nat.equal)) {
          case (?b) b;
          case (null) (chargeAcc.credit - chargeAcc.lockedCredit) : Nat;
        };
        AssocList.replace<AssetId, Nat>(
          newBalances,
          chargeToken,
          Nat.equal,
          ?(balance + ctx.chargeAmount(order.volume, order.price)),
        ) |> (newBalances := _.0);
      };

      // prepare cancellation of all orders by type (ask or bid)
      func prepareBulkCancelation(ctx : OrderCtx) {
        for ((orderId, order) in List.toIter(ctx.userList(userInfo))) {
          affectNewBalancesWithCancellation(ctx, orderId, order);
        };
        cancellationCommitActions := List.push(
          func() {
            label l while (true) {
              switch (ctx.userList(userInfo)) {
                case (?((orderId, _), _)) ignore cancelOrderInternal(ctx, userInfo, orderId);
                case (_) break l;
              };
            };
          },
          cancellationCommitActions,
        );
      };

      // prepare cancellation of all orders by given filter function by type (ask or bid)
      func prepareBulkCancelationWithFilter(ctx : OrderCtx, isCancel : (assetId : AssetId, orderId : OrderId) -> Bool) {
        // TODO can be optimized: cancelOrderInternal searches for order by it's id with linear complexity
        let orderIds : Vec.Vector<OrderId> = Vec.new();
        for ((orderId, order) in List.toIter(ctx.userList(userInfo))) {
          if (isCancel(order.assetId, orderId)) {
            affectNewBalancesWithCancellation(ctx, orderId, order);
            Vec.add(orderIds, orderId);
          };
        };
        cancellationCommitActions := List.push(
          func() {
            for (orderId in Vec.vals(orderIds)) {
              ignore cancelOrderInternal(ctx, userInfo, orderId);
            };
          },
          cancellationCommitActions,
        );
      };

      switch (cancellations) {
        case (null) {};
        case (? #all(null)) {
          asksDelta.isOrderCancelled := func(_, _) = true;
          bidsDelta.isOrderCancelled := func(_, _) = true;
          prepareBulkCancelation(askCtx);
          prepareBulkCancelation(bidCtx);
        };
        case (? #all(?aids)) {
          asksDelta.isOrderCancelled := func(assetId, _) = Array.find<Nat>(aids, func(x) = x == assetId) |> not Option.isNull(_);
          bidsDelta.isOrderCancelled := func(assetId, _) = Array.find<Nat>(aids, func(x) = x == assetId) |> not Option.isNull(_);
          prepareBulkCancelationWithFilter(askCtx, asksDelta.isOrderCancelled);
          prepareBulkCancelationWithFilter(bidCtx, bidsDelta.isOrderCancelled);
        };
        case (? #orders(orders)) {
          let cancelledAsks : RBTree.RBTree<OrderId, ()> = RBTree.RBTree(Nat.compare);
          let cancelledBids : RBTree.RBTree<OrderId, ()> = RBTree.RBTree(Nat.compare);
          asksDelta.isOrderCancelled := func(_, orderId) = cancelledAsks.get(orderId) |> not Option.isNull(_);
          bidsDelta.isOrderCancelled := func(_, orderId) = cancelledBids.get(orderId) |> not Option.isNull(_);

          for (i in orders.keys()) {
            let (ctx, orderId, cancelledTree) = switch (orders[i]) {
              case (#ask orderId) (askCtx, orderId, cancelledAsks);
              case (#bid orderId) (bidCtx, orderId, cancelledBids);
            };
            let ?oldOrder = AssocList.find(ctx.userList(userInfo), orderId, Nat.equal) else return #err(#cancellation({ index = i; error = #UnknownOrder }));
            affectNewBalancesWithCancellation(ctx, orderId, oldOrder);
            cancelledTree.put(orderId, ());
            cancellationCommitActions := List.push(
              func() = ignore cancelOrderInternal(ctx, userInfo, orderId),
              cancellationCommitActions,
            );
          };
        };
      };

      // validate and prepare placements
      for (i in placements.keys()) {
        let (ctx, (assetId, volume, price), ordersDelta, oppositeOrdersDelta) = switch (placements[i]) {
          case (#ask(args)) (askCtx, args, asksDelta, bidsDelta);
          case (#bid(args)) (bidCtx, args, bidsDelta, asksDelta);
        };

        // validate asset id
        if (assetId == trustedAssetId or assetId >= Vec.size(assets)) return #err(#placement({ index = i; error = #UnknownAsset }));

        // validate order volume
        let assetInfo = Vec.get(assets, assetId);
        if (ctx.lowOrderSign(assetId, assetInfo, volume, price)) return #err(#placement({ index = i; error = #TooLowOrder }));

        // validate user credit
        let chargeToken = ctx.chargeToken(assetId);
        let ?chargeAcc = AssocList.find<AssetId, Account>(userInfo.credits, chargeToken, Nat.equal) else return #err(#placement({ index = i; error = #NoCredit }));
        let chargeAmount = ctx.chargeAmount(volume, price);
        let balance = switch (AssocList.find<AssetId, Nat>(newBalances, chargeToken, Nat.equal)) {
          case (?b) b;
          case (null) (chargeAcc.credit - chargeAcc.lockedCredit) : Nat;
        };
        if (balance < chargeAmount) {
          return #err(#placement({ index = i; error = #NoCredit }));
        };
        AssocList.replace<AssetId, Nat>(newBalances, chargeToken, Nat.equal, ?(balance - chargeAmount))
        |> (newBalances := _.0);

        // build list of placed orders + orders to be placed during this call
        func buildOrdersList(userList : List.List<(OrderId, Order)>, delta : OrdersDelta) : Iter.Iter<(?OrderId, Order)> = userList
        |> List.toIter(_)
        |> Iter.map<(OrderId, Order), (?OrderId, Order)>(_, func(oid, o) = (?oid, o))
        |> iterConcat<(?OrderId, Order)>(_, List.toIter(delta.placed));

        // validate conflicting orders
        for ((orderId, order) in buildOrdersList(ctx.userList(userInfo), ordersDelta)) {
          if (
            order.assetId == assetId and price == order.price and (
              switch (orderId) {
                case (?oid) not ordersDelta.isOrderCancelled(assetId, oid);
                case (null) true;
              }
            )
          ) {
            return #err(#placement({ index = i; error = #ConflictingOrder(ctx.kind, orderId) }));
          };
        };

        for ((oppOrderId, oppOrder) in buildOrdersList(ctx.userOppositeList(userInfo), oppositeOrdersDelta)) {
          if (
            oppOrder.assetId == assetId and ctx.oppositeOrderConflictCriteria(price, oppOrder.price) and (
              switch (oppOrderId) {
                case (?oid) not oppositeOrdersDelta.isOrderCancelled(assetId, oid);
                case (null) true;
              }
            )
          ) {
            return #err(#placement({ index = i; error = #ConflictingOrder(ctx.oppositeKind, oppOrderId) }));
          };
        };

        let order : Order = {
          user = p;
          userInfoRef = userInfo;
          assetId = assetId;
          price = price;
          var volume = volume;
        };
        ordersDelta.placed := List.push((null, order), ordersDelta.placed);

        placementCommitActions[i] := func() = placeOrderInternal(ctx, userInfo, chargeAcc, assetId, assetInfo, order);
      };

      // commit changes, return results
      for (cancel in List.toIter(cancellationCommitActions)) {
        cancel();
      };
      #ok(Array.tabulate<OrderId>(placementCommitActions.size(), func(i) = placementCommitActions[i]()));
    };

    public func placeAsk(p : Principal, assetId : AssetId, volume : Nat, price : Float) : R.Result<OrderId, PlaceOrderError> {
      switch (manageOrders(p, null, [#ask(assetId, volume, price)])) {
        case (#ok orderIds) #ok(orderIds[0]);
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#placement { error })) switch (error) {
          case (#ConflictingOrder x) #err(#ConflictingOrder(x));
          case (#NoCredit) #err(#NoCredit);
          case (#TooLowOrder) #err(#TooLowOrder);
          case (#UnknownAsset) #err(#UnknownAsset);
        };
        case (_) Prim.trap("Can never happen");
      };
    };

    public func replaceAsk(p : Principal, orderId : OrderId, volume : Nat, price : Float) : R.Result<OrderId, ReplaceOrderError> {
      let assetId = switch (queryAsk(p, orderId)) {
        case (?ask) ask.assetId;
        case (null) return #err(#UnknownOrder);
      };
      switch (manageOrders(p, ? #orders([#ask(orderId)]), [#ask(assetId, volume, price)])) {
        case (#ok orderIds) #ok(orderIds[0]);
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#cancellation({ error }))) switch (error) {
          case (#UnknownOrder) #err(#UnknownOrder);
        };
        case (#err(#placement({ error }))) switch (error) {
          case (#ConflictingOrder x) #err(#ConflictingOrder(x));
          case (#NoCredit) #err(#NoCredit);
          case (#TooLowOrder) #err(#TooLowOrder);
          case (#UnknownAsset) #err(#UnknownAsset);
        };
      };
    };

    public func cancelAsk(p : Principal, orderId : OrderId) : R.Result<(), CancelOrderError> {
      switch (manageOrders(p, ? #orders([#ask(orderId)]), [])) {
        case (#ok orderIds) #ok();
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#placement { error })) Prim.trap("Can never happen");
        case (#err(#cancellation({ error }))) switch (error) {
          case (#UnknownOrder) #err(#UnknownOrder);
        };
      };
    };

    public func placeBid(p : Principal, assetId : AssetId, volume : Nat, price : Float) : R.Result<OrderId, PlaceOrderError> {
      switch (manageOrders(p, null, [#bid(assetId, volume, price)])) {
        case (#ok orderIds) #ok(orderIds[0]);
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#placement { error })) switch (error) {
          case (#ConflictingOrder x) #err(#ConflictingOrder(x));
          case (#NoCredit) #err(#NoCredit);
          case (#TooLowOrder) #err(#TooLowOrder);
          case (#UnknownAsset) #err(#UnknownAsset);
        };
        case (_) Prim.trap("Can never happen");
      };
    };

    public func replaceBid(p : Principal, orderId : OrderId, volume : Nat, price : Float) : R.Result<OrderId, ReplaceOrderError> {
      let assetId = switch (queryBid(p, orderId)) {
        case (?bid) bid.assetId;
        case (null) return #err(#UnknownOrder);
      };
      switch (manageOrders(p, ? #orders([#bid(orderId)]), [#bid(assetId, volume, price)])) {
        case (#ok orderIds) #ok(orderIds[0]);
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#cancellation({ error }))) switch (error) {
          case (#UnknownOrder) #err(#UnknownOrder);
        };
        case (#err(#placement({ error }))) switch (error) {
          case (#ConflictingOrder x) #err(#ConflictingOrder(x));
          case (#NoCredit) #err(#NoCredit);
          case (#TooLowOrder) #err(#TooLowOrder);
          case (#UnknownAsset) #err(#UnknownAsset);
        };
      };
    };

    public func cancelBid(p : Principal, orderId : OrderId) : R.Result<(), CancelOrderError> {
      switch (manageOrders(p, ? #orders([#bid(orderId)]), [])) {
        case (#ok orderIds) #ok();
        case (#err(#UnknownPrincipal)) #err(#UnknownPrincipal);
        case (#err(#placement { error })) Prim.trap("Can never happen");
        case (#err(#cancellation({ error }))) switch (error) {
          case (#UnknownOrder) #err(#UnknownOrder);
        };
      };
    };

    // processes auction for given asset
    public func processAsset(assetId : AssetId) : () {
      if (assetId == trustedAssetId) return;
      let startInstructions = settings.performanceCounter(0);

      let assetInfo = Vec.get(assets, assetId);
      let (asksAmount, bidsAmount, dealVolume, price) = calculateDeal<(OrderId, Order)>(
        List.toIter<(OrderId, Order)>(assetInfo.asks),
        List.toIter<(OrderId, Order)>(assetInfo.bids),
        func(_, order) = order.volume,
        func(_, order) = order.price,
      );
      if (asksAmount == 0 or bidsAmount == 0) {
        history := List.push((Prim.time(), sessionsCounter, assetId, 0, 0.0), history);
        return;
      };

      let assetStats = Vec.get(stats.assets, assetId);

      // process fulfilled asks
      var i = 0;
      var dealVolumeLeft = dealVolume;
      var asksTail = assetInfo.asks;
      label b while (i < asksAmount) {
        let ?((orderId, order), next) = asksTail else Prim.trap("Can never happen: list shorter than before");
        let userInfo = order.userInfoRef;
        // update ask in user info and calculate real ask volume
        let volume = if (i + 1 == asksAmount and dealVolumeLeft != order.volume) {
          order.volume -= dealVolumeLeft;
          dealVolumeLeft;
        } else {
          AssocList.replace<OrderId, Order>(userInfo.currentAsks, orderId, Nat.equal, null) |> (userInfo.currentAsks := _.0);
          asksTail := next;
          assetStats.asksAmount -= 1;
          dealVolumeLeft -= order.volume;
          order.volume;
        };
        // remove price from deposit
        let ?sourceAcc = AssocList.find<AssetId, Account>(userInfo.credits, assetId, Nat.equal) else Prim.trap("Can never happen");
        sourceAcc.credit -= volume;
        // unlock locked deposit
        sourceAcc.lockedCredit -= volume;
        // credit user with trusted tokens
        switch (getUserTrustedAccount_(userInfo)) {
          case (?acc) acc.credit += getTotalPrice(volume, price);
          case (null) {
            {
              var credit = getTotalPrice(volume, price);
              var lockedCredit = 0;
            }
            |> AssocList.replace<AssetId, Account>(userInfo.credits, trustedAssetId, Nat.equal, ?_)
            |> (userInfo.credits := _.0);
            stats.accountsAmount += 1;
          };
        };
        // update stats
        assetStats.totalAskVolume -= volume;
        // append to history
        userInfo.history := List.push((Prim.time(), sessionsCounter, #ask, assetId, volume, price), userInfo.history);
        i += 1;
      };
      assetInfo.asks := asksTail;

      // process fulfilled bids
      i := 0;
      dealVolumeLeft := dealVolume;
      var bidsTail = assetInfo.bids;
      label b while (i < bidsAmount) {
        let ?((orderId, order), next) = bidsTail else Prim.trap("Can never happen: list shorter than before");
        let userInfo = order.userInfoRef;
        // update bid in user info and calculate real bid volume
        let volume = if (i + 1 == bidsAmount and dealVolumeLeft != order.volume) {
          order.volume -= dealVolumeLeft;
          dealVolumeLeft;
        } else {
          AssocList.replace<OrderId, Order>(userInfo.currentBids, orderId, Nat.equal, null) |> (userInfo.currentBids := _.0);
          bidsTail := next;
          assetStats.bidsAmount -= 1;
          dealVolumeLeft -= order.volume;
          order.volume;
        };
        // remove price from deposit
        let ?trustedAcc = getUserTrustedAccount_(userInfo) else Prim.trap("Can never happen");
        trustedAcc.credit -= getTotalPrice(volume, price);
        // unlock locked deposit (note that it uses bid price)
        trustedAcc.lockedCredit -= getTotalPrice(volume, order.price);
        // credit user with tokens
        switch (AssocList.find<AssetId, Account>(userInfo.credits, assetId, Nat.equal)) {
          case (?acc) acc.credit += volume;
          case (null) {
            { var credit = volume; var lockedCredit = 0 }
            |> AssocList.replace<AssetId, Account>(userInfo.credits, assetId, Nat.equal, ?_)
            |> (userInfo.credits := _.0);
            stats.accountsAmount += 1;
          };
        };
        // update stats
        assetStats.totalBidVolume -= volume;
        // append to history
        userInfo.history := List.push((Prim.time(), sessionsCounter, #bid, assetId, volume, price), userInfo.history);
        i += 1;
      };
      assetInfo.bids := bidsTail;

      assetInfo.lastSwapRate := price;
      // append to asset history
      history := List.push((Prim.time(), sessionsCounter, assetId, dealVolume, price), history);
      assetStats.lastProcessingInstructions := Nat64.toNat(settings.performanceCounter(0) - startInstructions);
    };

    public func share() : StableDataV1 = {
      counters = (sessionsCounter, ordersCounter);
      assets = Vec.map<AssetInfo, StableAssetInfo>(
        assets,
        func(x) = {
          asks = x.asks;
          bids = x.bids;
          lastSwapRate = x.lastSwapRate;
        },
      );
      stats = {
        usersAmount = stats.usersAmount;
        accountsAmount = stats.accountsAmount;
        assets = Vec.map<{ var bidsAmount : Nat; var totalBidVolume : Nat; var asksAmount : Nat; var totalAskVolume : Nat; var lastProcessingInstructions : Nat }, { bidsAmount : Nat; totalBidVolume : Nat; asksAmount : Nat; totalAskVolume : Nat; lastProcessingInstructions : Nat }>(
          stats.assets,
          func(x) = {
            bidsAmount = x.bidsAmount;
            totalBidVolume = x.totalBidVolume;
            asksAmount = x.asksAmount;
            totalAskVolume = x.totalAskVolume;
            lastProcessingInstructions = x.lastProcessingInstructions;
          },
        );
      };
      users = users.share();
      history = history;
    };

    public func unshare(data : StableDataV1) {
      sessionsCounter := data.counters.0;
      ordersCounter := data.counters.1;
      assets := Vec.map<StableAssetInfo, AssetInfo>(
        data.assets,
        func(x) = {
          var asks = x.asks;
          var bids = x.bids;
          var lastSwapRate = x.lastSwapRate;
        },
      );
      stats := {
        var usersAmount = data.stats.usersAmount;
        var accountsAmount = data.stats.accountsAmount;
        assets = Vec.map<{ bidsAmount : Nat; totalBidVolume : Nat; asksAmount : Nat; totalAskVolume : Nat; lastProcessingInstructions : Nat }, { var bidsAmount : Nat; var totalBidVolume : Nat; var asksAmount : Nat; var totalAskVolume : Nat; var lastProcessingInstructions : Nat }>(
          data.stats.assets,
          func(x) = {
            var bidsAmount = x.bidsAmount;
            var totalBidVolume = x.totalBidVolume;
            var asksAmount = x.asksAmount;
            var totalAskVolume = x.totalAskVolume;
            var lastProcessingInstructions = x.lastProcessingInstructions;
          },
        );
      };
      users.unshare(data.users);
      history := data.history;
    };

  };

  // goes through list, finds one needed element and removes it if found. Returns updated list and flag is item was found and deleted
  private func listFindOneAndDelete<T>(list : List.List<T>, f : T -> Bool) : (List.List<T>, Bool) {
    switch list {
      case null { (null, false) };
      case (?(h, t)) {
        if (f(h)) {
          (t, true);
        } else {
          listFindOneAndDelete<T>(t, f) |> (?(h, _.0), _.1);
        };
      };
    };
  };

  // goes through list, finds first element for which f will return true, and inserts provided element BEFORE it
  private func insertWithPriority<T>(list : List.List<T>, item : T, f : T -> Bool) : List.List<T> {
    switch list {
      case null { ?(item, null) };
      case (?(h, t)) {
        if (f(h)) {
          ?(item, list);
        } else {
          insertWithPriority<T>(t, item, f) |> ?(h, _);
        };
      };
    };
  };

  /** concat two iterables into one */
  private func iterConcat<T>(a : Iter.Iter<T>, b : Iter.Iter<T>) : Iter.Iter<T> {
    var aEnded : Bool = false;
    object {
      public func next() : ?T {
        if (aEnded) {
          return b.next();
        };
        let nextA = a.next();
        switch (nextA) {
          case (?val) ?val;
          case (null) {
            aEnded := true;
            b.next();
          };
        };
      };
    };
  };
};
