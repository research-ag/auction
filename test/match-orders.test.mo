import Iter "mo:base/Iter";
import Prim "mo:prim";

import { clearAuction } "../src";


do {
  Prim.debugPrint("should use ask price for market bid...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (50.0, 10000)
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (1 / 0, 10000)
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 50.0;
};

do {
  Prim.debugPrint("should use bid price for market ask...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (0.0, 10000)
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (100.0, 10000)
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 0.0;
};

do {
  Prim.debugPrint("should fulfil many bids, use min price...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (0.0, 10000)
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (100.0, 2000),
    (90.0, 2000),
    (80.0, 2000),
    (70.0, 2000),
    (60.0, 2000),
    // do not filfil: out of volume
    (50.0, 2000),
    (40.0, 2000),
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 0.0;
};

do {
  Prim.debugPrint("should fulfil bids partially...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (0.0, 10000)
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (100.0, 6000),
    (90.0, 6000),
    (80.0, 6000),
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 0.0;
};

do {
  Prim.debugPrint("should fulfil many bids/asks, use average price...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (50.0, 10000),
    (60.0, 10000),
    (70.0, 10000),
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (100.0, 10000),
    (90.0, 10000),
    (80.0, 10000),
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 30000;
  assert price == 70.0;
};


do {
  Prim.debugPrint("should not fulfil anything if price does not match...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (80.0, 10000),
    (90.0, 10000),
    (100.0, 10000),
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (70.0, 10000),
    (60.0, 10000),
    (50.0, 10000),
  ]);

  let (volume, price) = clearAuction(asks, bids);
  assert volume == 0;
  assert price == 0.0;
};
