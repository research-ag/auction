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

  /// Matches asks and bids for auction functionality.
  ///
  /// This function iterates over asks and bids and matches them based on their prices and volumes.
  /// It returns the number of ask and bid orders to be fulfilled, the total volume of matched orders, and the execution price.
  ///
  /// # Parameters:
  /// - `asks: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the ask orders.
  /// - `bids: Iter.Iter<(price : Float, volume : Nat)>`: An iterator over the bid orders.
  ///
  /// # Returns:
  /// - `nAsks: Nat`: The number of executed ask orders (at least partially executed).
  /// - `nBids: Nat`: The number of executed bid orders (at least partially executed).
  /// - `volume: Nat`: The total volume of matched orders.
  /// - `price: Float`: The execution price of the matched orders.
  ///
  /// # Notes:
  /// - The function assumes that ask orders are sorted in ascending order of price, and bid orders are sorted in descending order of price.
  /// - The function returns (0, 0, 0, 0.0) if no match is found.
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
