/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Author: Timo Hanke (timohanke)
/// Contributors: Andy Gura (AndyGura) 

import Debug "mo:base/Debug";
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
  public type Order<X> = (price : X, volume : Nat);
  public type priceResult<X> = (price : X, volume : Nat);
  public type rangeResult<X> = {
    range : (X, X);
    volume : Nat;
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
  /// A bid order and ask order is a pair of price and volume.
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
  /// The price type is generic and is provided as a type parameter.
  /// For example, it can be Float, Nat or Int.
  /// The caller has to supply a comparison function `less` for the price type
  /// and a dummy value of the price type which can be returned as a dummy value when there are no matching orders.
  /// Since the algorithm uses only the comparison function `less`,
  /// it has no notion of a "valid price range".
  /// For price type Float, for example, the algorithm will work fine with negative prices, zero and infinity.
  ///
  /// The algorithm accepts all possible Float values as prices including 0, infinity and negative values.
  /// This is possible because only the relative order of prices matters, not their actual arithmetic value.
  ///
  /// The volume type is Nat.
  ///
  /// # Parameters:
  /// - `asks: Iter.Iter<Order<X>>`: An iterator over the ask orders. Must be in ascending (precisely: non-descending) order of price.
  /// - `bids: Iter.Iter<Order<X>>`: An iterator over the bid orders. Must be in descending (precisely: non-ascending) order of price.
  /// - `less: (X,X) -> Bool`: comparison function
  /// - `dummyPrice: X`: an arbitrary value of type X
  ///
  /// # Returns:
  /// - `volume: Nat`: The total matched volume at the determined price.
  /// - `price: X`: The determined execution price that maximises volume.
  ///
  /// The price is determined by the lowest matched ask order.
  /// The returned volume is 0 if and only if no order can be matched.
  /// In this case the price is meaningless and the provided dummy price is returned.
  ///
  /// The algorithm accepts orders with volume 0. Such orders have no influence on the return values.
  public func clearAuction<X>(
    asks : Iter.Iter<Order<X>>,
    bids : Iter.Iter<Order<X>>,
    less : (X, X) -> Bool,
  ) : ?(price : X, volume : Nat) {
    let ?first_ask = asks.next() else return null;
    var price = first_ask.0;
    var askVolume = first_ask.1; // (cumulative)
    var bidVolume = 0; // (cumulative)

    // loop invariant: askVolume >= bidVolume
    label L loop {
      let ?bid = bids.next() else break L;
      if (less(bid.0, price)) break L;
      bidVolume += bid.1;
      while (askVolume < bidVolume) {
        let ?ask = asks.next() else break L;
        if (less(bid.0, ask.0)) break L;
        price := ask.0;
        askVolume += ask.1;
      };
    };

    let vol = Nat.min(askVolume, bidVolume);
    if (vol == 0) return null;
    return ?(price, vol);
  };

  /// Clearing algorithm for a volume maximising uniform-price auction
  ///
  /// Compared to `clearAuction` this functions returns the full range of maximum trade volume.
  public func clearAuctionRange<X>(
    asks : Iter.Iter<Order<X>>,
    bids : Iter.Iter<Order<X>>,
    less : (X, X) -> Bool,
  ) : ?{
    range : (X, X);
    volume : Nat;
  } {
    let ?first_ask = asks.next() else return null;
    var askPrice = first_ask.0;
    var bidPrice : ?X = null;
    var askVolume = first_ask.1; // (cumulative)
    var bidVolume = 0; // (cumulative)

    // loop invariant: askVolume >= bidVolume
    label L loop {
      // first check whether the loop invariant holds with > or ==
      // if > then the next bid will become part of the clearing
      // if == then the next bid may become part of the clearing but needs another ask to match it
      let askNeeded = askVolume == bidVolume;

      let ?bid = bids.next() else break L;
      if (less(bid.0, askPrice)) break L;
      if (bid.1 == 0) continue L; // skip 0 volume bids
      bidVolume += bid.1;
      if (not askNeeded) bidPrice := ?bid.0; // if askNeeded then do this later below
      while (askVolume < bidVolume) {
        let ?ask = asks.next() else break L;
        if (less(bid.0, ask.0)) break L;
        if (askNeeded) bidPrice := ?bid.0;
        askPrice := ask.0;
        askVolume += ask.1;
      };
    };

    let volume = Nat.min(askVolume, bidVolume);
    if (volume == 0) return null;
    let range = switch (bidPrice) {
      case (?b) (askPrice, b);
      case (null) Debug.trap("should not happen");
    };
    return ?{ range; volume };
  };

};
