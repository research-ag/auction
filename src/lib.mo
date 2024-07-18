/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

module {

  public type Order = (price : Float, volume : Nat);

  class OrderSide(next_ : () -> ?Order) {
    public var price : Float = 0;
    public var volume : Nat = 0;
    public var index : Nat = 0;
    var next : Order = (0, 0);

    public func peek() : Bool {
      switch (next_()) {
        case (?x) { next := x; true };
        case (null) false;
      };
    };

    public func peekPrice() : Float = next.0;

    public func pop() {
      index += 1;
      price := next.0;
      volume += next.1;
    };
  };

  /// Matching algorithm for a volume-maximising auction
  ///
  /// Suppose we have a single trading pair with base currency X and quote currency Y.
  /// The algorithm requires as input an list of bid order sorted in descending order of price and a list of ask orders sorted in ascending order of price. 
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price and the volume that can be executed at that price.
  /// 
  /// In a volume-maximising auction all participants get their trades executed in one event,
  /// at the same time and at the same price.
  /// Or, if their orders missed the execution price then they are not eecuted at all.
  ///
  /// A bid order and ask order is a pair of price (type Float) and volume (type Nat).
  /// The price is denominated in Y and the volume is denominated in X.
  /// The price means the price for the smallest unit of Y and is measured in the smallest unit of X.
  /// The volume is measured in the smallest unit of Y.
  ///
  /// This function walks along ascending price and, for each price point, accumulates all ask orders up to that price.
  /// Simultaneously, it walks along descending price and, for each price point, accumulates all bid orders above that price.
  /// The algorithm is designed such that when the two walks meet then that price point is the one that maximises the exchange volume,
  /// if everyone gets their orders executed at the same price or not at all.
  ///
  /// # Parameters:
  /// - `asks: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the ask orders. Must be in ascending order of price.
  /// - `bids: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the bid orders. Must be in descending order of price.
  ///
  /// # Returns:
  /// - `nAsks: Nat`: The number of executed ask orders from the input iterator (at least partially executed).
  /// - `nBids: Nat`: The number of executed bid orders from the input iterator (at least partially executed).
  /// - `volume: Nat`: The total volume at the determined price.
  /// - `price: Float`: The execution price that maximises volume.
  ///
  /// # Notes:
  /// - The function returns (0, 0, 0, 0.0) if no order match, i.e. when the volume is 0.
  /// - The function is primarily designed for limit order but it can handle market orders as well. A market ask order is modeled by having an ask price of 0. A market bid order is modeled by having an ask price of +inf.
  /// - The execution price is determined as follows:
  ///   - If both the highest bid and the lowest ask are market orders (price 0.0 for sell and +inf for buy), no execution occurs.
  ///   - If the highest bid is a market order, the price is the price of the highest ask to be fulfilled.
  ///   - If the lowest ask is a market order, the price is the price of the lowest bid to be fulfilled.
  ///   - Otherwise, the price is the average of the last fulfilled bid and the last fulfilled ask.
  public func matchOrders(
    asks_ : Iter.Iter<Order>,
    bids_ : Iter.Iter<Order>,
  ) : (
    nAsks : Nat,
    nBids : Nat,
    volume : Nat,
    price : Float,
  ) {

    let inf : Float = 1 / 0; // +inf

    let asks = OrderSide(asks_.next);
    let bids = OrderSide(bids_.next);

    label L loop {
      let inc_ask = asks.volume <= bids.volume;
      let inc_bid = bids.volume <= asks.volume;
      if (inc_ask and not asks.peek()) break L;
      if (inc_bid and not bids.peek()) break L;
      if (bids.peekPrice() < asks.peekPrice()) break L;
      if (inc_ask) asks.pop();
      if (inc_bid) bids.pop();
    };

    // highest bid was lower than lowest ask
    if (asks.index == 0) {
      return (0, 0, 0, 0.0);
    };
    // Note: asks.index > 0 implies bids.index > 0

    (
      asks.index,
      bids.index,
      Nat.min(asks.volume, bids.volume),
      switch (asks.price == 0.0, bids.price == inf) {
        // market sell against market buy => no execution
        case (true, true) return (0, 0, 0, 0.0);
        case (true, _) bids.price; // market sell against highest bid => use bid price
        case (_, true) asks.price; // market buy against lowest ask => use ask price
        case (_) (asks.price + bids.price) / 2; // limit sell against limit buy => use middle price
      },
    );
  };

};
