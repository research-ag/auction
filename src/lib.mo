/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Authors: Andy Gura (AndyGura), Timo Hanke (timohanke)

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

/// Clearing algorithm for a volume maximising uniform-price auction
///
/// This is an auction in which participants place limit orders ahead of time.
/// When the auction happens then the clearing algorithm from this package runs.
/// It finds the single price point at which the maximum volume of orders can be executed.
///
/// The application code is responsible for:
/// - Collecting orders from participants. It usually keeps orders hidden from the public until clearing happens.
/// - Sorting the orders by ascending price for ask orders and descending price for bid orders.
/// - Executing the trades at the determined price. Usually all trades get executed at the same price.
module {

  /// Orders are specified by a limit price measured in quote currency and a volume measured in base currency.
  public type Order = (price : Float, volume : Nat);

  func assert_valid_price(x : Float) {
    assert x > 0 and x != 1 / 0;
  };

  /// Clearing algorithm for a volume maximising uniform-price auction
  ///
  /// Suppose we have a single trading pair with base currency X and quote currency Y.
  /// The algorithm requires as input an list of bid order sorted in descending order of price and a list of ask orders sorted in ascending order of price.
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price point and the volume that can be executed at that price.
  ///
  /// In a volume maximising auction all participants get their trades executed in one event,
  /// at the same time and at the same price.
  /// Or, if their orders missed the execution price then they are not executed at all.
  ///
  /// A bid order and ask order is a pair of price (type Float) and volume (type Nat).
  /// The price is denominated in Y and the volume is denominated in X.
  /// The price means the price for the smallest unit of Y and is measured in the smallest unit of X.
  /// The volume is measured in the smallest unit of Y.
  ///
  /// Roughly speaking, the algorithm works as follows:
  /// We walk along ascending price on the ask side and, for each price point, accumulate the volume of all ask orders up to that price.
  /// Simultaneously, we walk along descending price on the bid side and, for each price point, accumulate the volume of all bid orders above that price.
  /// The two walks are coordinated such that the side which has the lower accumulated volume walks takes the next step, until that side's volume overtakes the accumulated volume of the side.
  /// Then the other side takes the next step, etc.
  /// When the two walks meet in price then we have found the price point at which the maximum volume can be executed.
  /// During execution all participants will get executed at the same price, regardless of their actual order price.
  /// All orders whose volume was accumulated during the walks will be executed.
  /// We say these order were "matched".
  ///
  /// # Parameters:
  /// - `asks: Iter.Iter<Order>`: An iterator over the ask orders. Must be in ascending (precisely: non-descending) order of price.
  /// - `bids: Iter.Iter<Order>`: An iterator over the bid orders. Must be in descending (precisely: non-ascending) order of price.
  ///
  /// # Returns:
  /// - `trap` if an order price <= 0 or infinity is encountered.
  /// - `volume: Nat`: The total matched volume at the determined price.
  /// - `price: Float`: The determined execution price that maximises volume.
  ///
  /// The price is determined by the lowest matched ask order.
  /// If no order can be matched then volume and price are both returned as zero.
  public func clearAuction(
    asks : Iter.Iter<Order>,
    bids : Iter.Iter<Order>,
  ) : (price : Float, volume : Nat) {
    var bidVolume = 0; // cumulative volume
    var askVolume = 0; // cumulative volume
    var price = 0.0;

    label L loop {
      let ?bid = bids.next() else break L;
      assert_valid_price(bid.0);
      if (bid.0 < price) break L;
      bidVolume += bid.1;
      while (askVolume < bidVolume) {
        let ?ask = asks.next() else break L;
        assert_valid_price(ask.0);
        if (ask.0 > bid.0) break L;
        price := ask.0;
        askVolume += ask.1;
      };
    };

    (price, Nat.min(askVolume, bidVolume));
  };

  /// Clearing algorithm for a volume maximising uniform-price auction
  ///
  /// Compared to `clearAuction` this functions returns the full range of maximum trade volume.
  public func clearAuctionRange(
    asks : Iter.Iter<Order>,
    bids : Iter.Iter<Order>,
  ) : {
    range : (Float, Float);
    volume : Nat;
  } {
    var bidVolume = 0; // cumulative volume
    var askVolume = 0; // cumulative volume
    var price = 0.0;
    var price2 = 0.0;

    label L loop {
      let ?bid = bids.next() else break L;
      assert_valid_price(bid.0);
      if (bid.0 < price) break L;
      let wasEqual = bidVolume == askVolume;
      if (not wasEqual) price2 := bid.0;
      bidVolume += bid.1;
      while (askVolume < bidVolume) {
        let ?ask = asks.next() else break L;
        assert_valid_price(ask.0);
        if (ask.0 > bid.0) break L;
        if (wasEqual) price2 := bid.0;
        price := ask.0;
        askVolume += ask.1;
      };
    };

    {
      range = (price, price2);
      volume = Nat.min(askVolume, bidVolume);
    };
  };

};
