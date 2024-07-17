/// A module which implements auction functionality
///
/// Copyright: 2023-2024 MR Research AG
/// Main author: Andy Gura
/// Contributors: Timo Hanke

import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

module {

  type Order = (price : Float, volume : Nat);

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
