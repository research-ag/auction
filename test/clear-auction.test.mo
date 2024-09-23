import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Prim "mo:prim";

import Auction "../src";

type Order = Auction.Order<Float>;

func clearAuction(
  asks : Iter.Iter<Order>,
  bids : Iter.Iter<Order>,
) : ?Auction.priceResult<Float> {
  Auction.clear<Float>(asks, bids, Float.less);
};

do {
  Prim.debugPrint("fulfil many bids, take price where bids exceed asks.");
  let orders : ([Order], [Order]) = (
    [(20, 100)], // asks ascending
    [(100, 20), (90, 20), (80, 20), (70, 20), (60, 20), (50, 20), (40, 20)] // bids descending
  );
  let expect = (50.0, 100);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("fulfil bids partially, take price where bids exceed asks.");
  let orders : ([Order], [Order]) = (
    [(50, 100)], // asks ascending
    [(100, 60), (90, 60), (80, 60)] // bids descending
  );
  let expect = (90.0, 100);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("fulfil many bids/asks, use ask price.");
  let orders : ([Order], [Order]) = (
    [(50, 100), (60, 100), (70, 100)], // asks ascending
    [(100, 100), (90, 100), (80, 100)] // bids descending
  );
  let expect = (70.0, 300);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("do not fulfil anything if price does not match.");
  let orders : ([Order], [Order]) = (
    [(80, 100), (90, 100), (100, 100)], // asks ascending
    [(70, 100), (60, 100), (50, 100)] // bids descending
  );
  assert clearAuction(orders.0.vals(), orders.1.vals()) == null;
};

do {
  Prim.debugPrint("Example 1");
  let orders : ([Order], [Order]) = (
    [(10, 10), (20, 10), (30, 10)], // asks ascending
    [(30, 10), (20, 10), (10, 10)], // bids descending
  );
  let expect = (20.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Example 2");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 10), (20, 10), (10, 10)], // bids descending
  );
  let expect = (15.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Example 3");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 15), (20, 10), (10, 10)], // bids descending
  );
  let expect = (20.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Example 4");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 20), (20, 10), (10, 10)], // bids descending
  );
  let expect = (20.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Example 5");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 25), (20, 10), (10, 10)], // bids descending
  );
  let expect = (25.0, 25);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Negative prices");
  let orders : ([Order], [Order]) = (
    [(-30, 10), (-20, 10), (-10, 10)], // asks ascending
    [(-10, 10), (-20, 10), (-30, 10)], // bids descending
  );
  let expect = (-20.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Infinite prices");
  let orders : ([Order], [Order]) = (
    [(-1 / 0, 10), (-20, 10), (1 / 0, 10)], // asks ascending
    [(1 / 0, 10), (-20, 10), (-1 / 0, 10)], // bids descending
  );
  let expect = (-20.0, 20);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Zero volume ask could affect price.");
  let orders : ([Order], [Order]) = (
    [(10, 5), (15, 0)], // asks ascending
    [(20, 5)], // bids descending
  );
  let expect = (10.0, 5);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Zero volume ask could affect price.");
  let orders : ([Order], [Order]) = (
    [(10, 5) ], // asks ascending
    [(20, 5), (15, 0)], // bids descending
  );
  let expect = (10.0, 5);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Zero volume ask could affect range.");
  let orders : ([Order], [Order]) = (
    [(10, 10), (10, 0)], // asks ascending
    [(30, 10), (25, 10)], // bids descending
  );
  let expect = (25.0, 10);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Zero volume bid could affect range.");
  let orders : ([Order], [Order]) = (
    [(10, 10)], // asks ascending
    [(30, 5), (25, 0)], // bids descending
  );
  let expect = (10.0, 5);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};

do {
  Prim.debugPrint("Additional bit increases price even if unused.");
  let orders : ([Order], [Order]) = (
    [(10, 10)], // asks ascending
    [(30, 10), (25, 10)], // bids descending
  );
  let expect = (25.0, 10);
  assert clearAuction(orders.0.vals(), orders.1.vals()) == ?(expect.0, expect.1);
};
