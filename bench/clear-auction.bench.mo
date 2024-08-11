import Array "mo:base/Array";
import Bench "mo:bench";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Prim "mo:prim";
import Text "mo:base/Text";

import Clear "../src";

module {

  type Order = Clear.Order<Float>;

  func clearAuction(
    asks : Iter.Iter<Order>,
    bids : Iter.Iter<Order>,
  ) : ?Clear.priceResult<Float> {
    Clear.clearAuction<Float>(asks, bids, Float.less);
  };

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Orders matching");
    bench.description("Read bids and asks in lists with size N/2 each, determine amount of asks and bids to be fulfilled, deal volume and price");

    let rows = [
      "Fulfil `0` asks, `0` bids",
      "Fulfil `1` ask, `1` bid",
      "Fulfil `N/2` asks, `1` bid",
      "Fulfil `1` ask, `N/2` bids",
      "Fulfil `N/2` asks, `N/2` bids",
    ];

    let cols = [
      "10",
      "50",
      "100",
      "500",
      "1000",
      "10000",
    ];

    bench.rows(rows);
    bench.cols(cols);

    let envs = Array.tabulate<(asks : Iter.Iter<(price : Float, volume : Nat)>, bids : Iter.Iter<(price : Float, volume : Nat)>, res : ?(price : Float, volume : Nat))>(
      rows.size() * cols.size(),
      func(i) {
        let row : Nat = i % rows.size();
        let col : Nat = i / rows.size();

        let ?nOrders = Nat.fromText(cols[col]) else Prim.trap("Cannot parse nOrders");
        let (nAsks, nBids) = switch (row) {
          case (0) (0, 0);
          case (1) (1, 1);
          case (2) (nOrders / 2, 1);
          case (3) (1, nOrders / 2);
          case (4) (nOrders / 2, nOrders / 2);
          case (_) Prim.trap("Cannot determine nAsks, nBids");
        };

        let dealVolume : Nat = 10_000;
        // bids with greater price and asks with lower price will be fulfilled
        let criticalPrice : Float = 1_000.0;

        let asks = Array.tabulate<(price : Float, volume : Nat)>(
          nOrders / 2,
          func(n) = (criticalPrice - Prim.intToFloat((nAsks - 1 - n)) * 0.1, dealVolume / Nat.max(nAsks, 1)),
        );
        let bids = Array.tabulate<(price : Float, volume : Nat)>(
          nOrders / 2,
          func(n) = (criticalPrice + Prim.intToFloat((nBids - 1 - n)) * 0.1, dealVolume / Nat.max(nBids, 1)),
        );
        (
          Array.vals(asks),
          Array.vals(bids),
          switch (nAsks, nBids) {
            case ((0, _) or (_, 0)) null;
            case (_) ?(criticalPrice, dealVolume);
          },
        );
      },
    );

    bench.runner(
      func(row, col) {
        let ?ci = Array.indexOf<Text>(col, cols, Text.equal) else Prim.trap("Cannot determine column: " # col);
        let ?ri = Array.indexOf<Text>(row, rows, Text.equal) else Prim.trap("Cannot determine row: " # row);
        let (asks, bids, expectedResult) = envs[ci * rows.size() + ri];

        let result = clearAuction(asks, bids); 

        // make sure everything worked as expected
        assert result == expectedResult;
      }
    );

    bench;
  };
};
