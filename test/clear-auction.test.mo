import Iter "mo:base/Iter";
import Prim "mo:prim";

import { clearAuction } "../src";

type Order = (Float, Nat);

do {
  Prim.debugPrint("should fulfil many bids, use min price...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (20.0, 10000)
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

  let (price, volume) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 20.0;
};

do {
  Prim.debugPrint("should fulfil bids partially...");
  let asks = Iter.fromArray<(Float, Nat)>([
    (50.0, 10000)
  ]);
  let bids = Iter.fromArray<(Float, Nat)>([
    (100.0, 6000),
    (90.0, 6000),
    (80.0, 6000),
  ]);

  let (price, volume) = clearAuction(asks, bids);
  assert volume == 10000;
  assert price == 50.0;
};

do {
  Prim.debugPrint("should fulfil many bids/asks, use ask price...");
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

  let (price, volume) = clearAuction(asks, bids);
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

  let (price, volume) = clearAuction(asks, bids);
  assert volume == 0;
  assert price == 0.0;
};

do {
 Prim.debugPrint("Example 1"); 
 let orders : ([Order], [Order]) = (
  [(10, 10), (20, 10), (30, 10)], // asks ascending
  [(30, 10), (20, 10), (10, 10)], // bids descending
 );
 let expect = (20.0, 20);
 assert clearAuction(orders.0.vals(), orders.1.vals()) == expect;
};
do {
 Prim.debugPrint("Example 2"); 
 let orders : ([Order], [Order]) = (
  [(5, 10), (15, 10), (25, 10)], // asks ascending
  [(30, 10), (20, 10), (10, 10)], // bids descending
 );
 let expect = (15.0, 20);
 assert clearAuction(orders.0.vals(), orders.1.vals()) == expect;
};
do {
 Prim.debugPrint("Example 3"); 
 let orders : ([Order], [Order]) = (
  [(5, 10), (15, 10), (25, 10)], // asks ascending
  [(30, 15), (20, 10), (10, 10)], // bids descending
 );
 let expect = (15.0, 20);
 assert clearAuction(orders.0.vals(), orders.1.vals()) == expect;
};
do {
 Prim.debugPrint("Example 4"); 
 let orders : ([Order], [Order]) = (
  [(5, 10), (15, 10), (25, 10)], // asks ascending
  [(30, 20), (20, 10), (10, 10)], // bids descending
 );
 let expect = (15.0, 20);
 assert clearAuction(orders.0.vals(), orders.1.vals()) == expect;
};
do {
 Prim.debugPrint("Example 5"); 
 let orders : ([Order], [Order]) = (
  [(5, 10), (15, 10), (25, 10)], // asks ascending
  [(30, 25), (20, 10), (10, 10)], // bids descending
 );
 let expect = (25.0, 25);
 assert clearAuction(orders.0.vals(), orders.1.vals()) == expect;
};
