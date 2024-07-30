/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

/// Clearing algorithm for a volume maximising uniform-price auction
///
/// This is an auction in which participants place limit orders or market orders ahead of time.
/// When the auction happens then the clearing algorithm from this package runs.
/// It finds the single price point at which the maximum volume of orders can be executed.
///
/// The application code is responsible for:
/// - Collecting orders from participants. It usually keeps order hidden from the public until clearing happens.
/// - Sorting the orders by ascending price for ask orders and descending price for bid orders.
/// - Executing the trades at the determined price. Usually all trades get executed at the same price.
module {

  /// Orders are specified by a limit price measured in quote currency and a volume measured in base currency.
  public type Order = (price : Float, volume : Nat);

  // A helper class to iterate over the order book. The function `stepAndRead`
  // reads the next order from the iterator if `shouldStep` is true, otherwise
  // it returns the last order. In case of the last order it overrides the
  // volume with 0 to make it easier for the caller to accumulate volume without
  // double-counting volume.
  class OrderBook(iter : Iter.Iter<Order>) {
    var lastPrice : Float = 0;
    public func stepAndRead(shouldStep : Bool) : ?Order {
      if (shouldStep) {
        let ?x = iter.next() else return null;
        lastPrice := x.0;
        return ?x;
      } else {
        return ?(lastPrice, 0);
      };
    };
  };

  /// Clearing algorithm for a volume maximising uniform-price auction
  ///
  /// Suppose we have a single trading pair with base currency X and quote currency Y.
  /// The algorithm requires as input an list of bid order sorted in descending order of price and a list of ask orders sorted in ascending order of price.
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price and the volume that can be executed at that price.
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
  /// - `asks: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the ask orders. Must be in ascending (precisely: non-descending) order of price.
  /// - `bids: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the bid orders. Must be in descending (precisely: non-ascending) order of price.
  ///
  /// # Returns:
  /// - `volume: Nat`: The total matched volume at the determined price.
  /// - `price: Float`: The determined execution price that maximises volume.
  ///
  /// The price is determined by the lowest matched matched ask order.
  public func clearAuction(
    asksIter : Iter.Iter<Order>,
    bidsIter : Iter.Iter<Order>,
  ) : (
    price : Float,
    volume : Nat,
  ) {

    let askSide = OrderBook(asksIter);
    let bidSide = OrderBook(bidsIter);

    var clearingPrice : Float = 0;
    var bidVolume = 0; // cumulative volume on bid side
    var askVolume = 0; // cumulative volume on ask side

    label L loop {
      let shouldStepBids = bidVolume <= askVolume;
      let shouldStepAsks = askVolume <= bidVolume;
      let ?bid = bidSide.stepAndRead(shouldStepBids) else break L;
      let ?ask = askSide.stepAndRead(shouldStepAsks) else break L;
      if (bid.0 < ask.0) break L;
      clearingPrice := ask.0;
      bidVolume += bid.1;
      askVolume += ask.1;
    };

    (clearingPrice, Nat.min(askVolume, bidVolume));
  };

};
