import Prim "mo:prim";

import Clear "../src";

type Order = Clear.Order<Float>;
let clearAuction = Clear.clearAuctionFloat;
let clearAuctionRange = Clear.clearAuctionRange;

do {
  Prim.debugPrint("should fulfil many bids, use min price...");
  let orders : ([Order], [Order]) = (
    [(20, 100)], // asks ascending
    [(100, 20), (90, 20), (80, 20), (70, 20), (60, 20), (50, 20), (40, 20)] // bids descending
  );
  let expect = (20.0, 60.0, 100);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("should fulfil bids partially...");
  let orders : ([Order], [Order]) = (
    [(50, 100)], // asks ascending
    [(100, 60), (90, 60), (80, 60)] // bids descending
  );
  let expect = (50.0, 90.0, 100);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("should fulfil many bids/asks, use ask price...");
  let orders : ([Order], [Order]) = (
    [(50, 100), (60, 100), (70, 100)], // asks ascending
    [(100, 100), (90, 100), (80, 100)] // bids descending
  );
  let expect = (70.0, 80.0, 300);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("should not fulfil anything if price does not match...");
  let orders : ([Order], [Order]) = (
    [(80, 100), (90, 100), (100, 100)], // asks ascending
    [(70, 100), (60, 100), (50, 100)] // bids descending
  );
  let expect = (0.0, 0.0, 0);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Example 1");
  let orders : ([Order], [Order]) = (
    [(10, 10), (20, 10), (30, 10)], // asks ascending
    [(30, 10), (20, 10), (10, 10)], // bids descending
  );
  let expect = (20.0, 20.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Example 2");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 10), (20, 10), (10, 10)], // bids descending
  );
  let expect = (15.0, 20.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Example 3");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 15), (20, 10), (10, 10)], // bids descending
  );
  let expect = (15.0, 20.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Example 4");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 20), (20, 10), (10, 10)], // bids descending
  );
  let expect = (15.0, 30.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Example 5");
  let orders : ([Order], [Order]) = (
    [(5, 10), (15, 10), (25, 10)], // asks ascending
    [(30, 25), (20, 10), (10, 10)], // bids descending
  );
  let expect = (25.0, 30.0, 25);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Negative prices");
  let orders : ([Order], [Order]) = (
    [(-30, 10), (-20, 10), (-10, 10)], // asks ascending
    [(-10, 10), (-20, 10), (-30, 10)], // bids descending
  );
  let expect = (-20.0, -20.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Infinite prices");
  let orders : ([Order], [Order]) = (
    [(-1/0, 10), (-20, 10), (1/0, 10)], // asks ascending
    [(1/0, 10), (-20, 10), (-1/0, 10)], // bids descending
  );
  let expect = (-20.0, -20.0, 20);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};

do {
  Prim.debugPrint("Zero volume");
  let orders : ([Order], [Order]) = (
    [(10, 0), (15, 0), (15, 10), (20, 0), (20, 10)], // asks ascending
    [(25, 0), (20, 10), (15, 20)], // bids descending
  );
  let expect = (15.0, 20.0, 10);
  assert clearAuctionRange(orders.0.vals(), orders.1.vals()) == { range = (expect.0, expect.1); volume = expect.2};
  assert clearAuction(orders.0.vals(), orders.1.vals()) == (expect.0, expect.2);
};
