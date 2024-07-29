/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

/// Matching algorithm for a volume maximising single-price auction
///
/// This is an auction in which participants place limit orders or market orders ahead of time
/// and the order book is usually hidden from the public.
/// When the auction happens then the matching algorithm from this package runs.
/// It finds the single price point at which the maximum volume of orders can be executed.
/// Then all participants will get their trades executed in one event, at the same time and at the same price.
module {

  public type Order = (price : Float, volume : Nat);

  class Orders(iter : Iter.Iter<Order>) {
    var lastPrice : Float = 0;
    public func advance(b : Bool) : ?(Float, Nat) {
      if (b) {
        let ?x = iter.next() else return null;
        lastPrice := x.0;
        return ?x;
      } else {
        return ?(lastPrice, 0);
      };
    };
  };

  /// Matching algorithm for a volume maximising single-price auction
  ///
  /// Suppose we have a single trading pair with base currency X and quote currency Y.
  /// The algorithm requires as input an list of bid order sorted in descending order of price and a list of ask orders sorted in ascending order of price.
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price and the volume that can be executed at that price.
  ///
  /// In a volume maximising auction all participants get their trades executed in one event,
  /// at the same time and at the same price.
  /// Or, if their orders missed the execution price then they are not eecuted at all.
  ///
  /// A bid order and ask order is a pair of price (type Float) and volume (type Nat).
  /// The price is denominated in Y and the volume is denominated in X.
  /// The price means the price for the smallest unit of Y and is measured in the smallest unit of X.
  /// The volume is measured in the smallest unit of Y.
  ///
  /// Roughly speaking, the algorithm works as follows:
  /// We walk along ascending price on the ask side and, for each price point, accumulates the volume of all ask orders up to that price.
  /// Simultaneously, we walk along descending price on the bid side and, for each price point, accumulates the volume of all bid orders above that price.
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
  /// - `nAsks: Nat`: The number of ask orders, starting from the beginning of the input iterator, that were matched. The last one could be partially matched and all other ones were fully matched.
  /// - `nBids: Nat`: The number of bid orders, starting from the beginning of the input iterator, that were matched. The last one could be partially matched and all other ones were fully matched.
  /// - `volume: Nat`: The total matched volume at the determined price.
  /// - `price: Float`: The determined execution price that maximises volume.
  ///
  /// The function is primarily designed for limit orders but it can handle market orders as well.
  /// A market ask order is modeled by having an ask price of 0.
  /// A market bid order is modeled by having an ask price of +inf.
  ///
  /// The price is determined by the lowest matched bid order and the highest matched ask order.
  /// - If no orders were matched, i.e. the volume is 0, then the function returns (0, 0, 0, 0.0).
  /// - If on both sides only market orders are matched, i.e. no limit order on either side was matched, then no execution occurs. This is because it is impossible to determine a price from 0 and +inf.
  /// - If the lowest matched bid is a market order, then the execution price is equal to the price of the highest matched ask.
  /// - If the highest matched ask is a market order, then the execution price is equal to the price of the lowest matched bid.
  /// - Otherwise, the price is the middle between the highest matches ask and lowest matched bid.
  public func clearAuction(
    asksIter : Iter.Iter<Order>,
    bidsIter : Iter.Iter<Order>,
  ) : (
    volume : Nat,
    price : Float,
  ) {

    let askSide = Orders(asksIter);
    let bidSide = Orders(bidsIter);

    var clearingPrice : Float = 0;
    var bidVolume = 0; // cumulative volume on bid side
    var askVolume = 0; // cumulative volume on ask side

    label L loop {
      let bidVolSmaller = bidVolume <= askVolume;
      let askVolSmaller = askVolume <= bidVolume;
      let ?bid = bidSide.advance(bidVolSmaller) else break L;
      let ?ask = askSide.advance(askVolSmaller) else break L;
      if (bid.0 < ask.0) break L;
      clearingPrice := ask.0;
      bidVolume += bid.1;
      askVolume += ask.1;
    };

    (Nat.min(askVolume, bidVolume), clearingPrice);
  };

};
