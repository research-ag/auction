import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

module {

  public func calculateDeal<Order>(
    asks : Iter.Iter<Order>,
    bids : Iter.Iter<Order>,
    getVolume : (Order) -> Nat,
    getPrice : (Order) -> Float,
  ) : (
    asksAmount : Nat,
    bidsAmount : Nat,
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

    let (asksAmount, bidsAmount) = label L : (Nat, Nat) loop {
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
      if (getPrice(nextAsk) > getPrice(nextBid)) break L orig;
      if (inc_ask) asksVolume += getVolume(nextAsk);
      if (inc_bid) bidsVolume += getVolume(nextBid);
    };

    // highest bid was lower than lowest ask
    if (asksAmount == 0) {
      return (0, 0, 0, 0.0);
    };
    // Note: asksAmount > 0 implies bidsAmount > 0

    (
      asksAmount,
      bidsAmount,
      Nat.min(asksVolume, bidsVolume),
      switch (getPrice(lastAskToFulfil) == 0.0, getPrice(lastBidToFulfil) == inf) {
        // market sell against market buy => no execution
        case (true, true) return (0, 0, 0, 0.0);
        case (true, _) getPrice(lastBidToFulfil); // market sell against highest bid => use bid price
        case (_, true) getPrice(lastAskToFulfil); // market buy against lowest ask => use ask price
        case (_) (getPrice(lastAskToFulfil) + getPrice(lastBidToFulfil)) / 2; // limit sell against limit buy => use middle price
      },
    );
  };

};
