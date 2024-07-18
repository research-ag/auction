/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

module {

  type Order = (price : Float, volume : Nat);

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
    asks : Iter.Iter<Order>,
    bids : Iter.Iter<Order>,
  ) : (
    nAsks : Nat,
    nBids : Nat,
    volume : Nat,
    price : Float,
  ) {

    let inf : Float = 1 / 0; // +inf

    var a = 0; // number of executed ask orders (at least partially executed)
    let ?na = asks.next() else return (0, 0, 0, 0.0);
    var nextAsk = na;

    var b = 0; // number of executed bid orders (at least partially executed)
    let ?nb = bids.next() else return (0, 0, 0, 0.0);
    var nextBid = nb;

    var asksVolume = 0;
    var bidsVolume = 0;

    var lastBidToFulfil = nextBid;
    var lastAskToFulfil = nextAsk;

    let (nAsks, nBids) = label L : (Nat, Nat) loop {
      let orig = (a, b);
      let inc_ask = asksVolume <= bidsVolume;
      let inc_bid = bidsVolume <= asksVolume;
      lastAskToFulfil := nextAsk;
      lastBidToFulfil := nextBid;
      if (inc_ask) {
        a += 1;
        if (a > 1) {
          let ?na = asks.next() else break L orig;
          nextAsk := na;
        };
      };
      if (inc_bid) {
        b += 1;
        if (b > 1) {
          let ?nb = bids.next() else break L orig;
          nextBid := nb;
        };
      };
      if (nextAsk.0 > nextBid.0) break L orig;
      if (inc_ask) asksVolume += nextAsk.1;
      if (inc_bid) bidsVolume += nextBid.1;
    };

    // highest bid was lower than lowest ask
    if (nAsks == 0) {
      return (0, 0, 0, 0.0);
    };
    // Note: nAsks > 0 implies nBids > 0

    (
      nAsks,
      nBids,
      Nat.min(asksVolume, bidsVolume),
      switch (lastAskToFulfil.0 == 0.0, lastBidToFulfil.0 == inf) {
        // market sell against market buy => no execution
        case (true, true) return (0, 0, 0, 0.0);
        case (true, _) lastBidToFulfil.0; // market sell against highest bid => use bid price
        case (_, true) lastAskToFulfil.0; // market buy against lowest ask => use ask price
        case (_) (lastAskToFulfil.0 + lastBidToFulfil.0) / 2; // limit sell against limit buy => use middle price
      },
    );
  };

};
