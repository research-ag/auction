import Array "mo:core/Array";
import Float "mo:core/Float";
import Nat "mo:core/Nat";
import Types "mo:core/Types";
import Prim "mo:prim";

import Auction "../src";

module {
  type Order = Auction.Order<Float>;
  
  type Schema = {
    name : Text;
    description : Text;
    rows : [Text];
    cols : [Text];
  };

  class BenchV1(schema : Schema, run : (Nat, Nat) -> ()) {
    public func getVersion() : Nat = 1;
    public func getSchema() : Schema = schema;
    public let runCell = run;
  };

  func clearAuction(
    asks : Types.Iter<Order>,
    bids : Types.Iter<Order>,
  ) : ?Auction.priceResult<Float> {
    Auction.clear<Float>(asks, bids, Float.less);
  };

  public func init() : BenchV1 {
    let schema : Schema = {
      name = "Orders matching";
      description = "Read bids and asks in lists with size N/2 each, determine amount of asks and bids to be fulfilled, deal volume and price";
      rows = [
        "Fulfil `0` asks, `0` bids",
        "Fulfil `1` ask, `1` bid",
        "Fulfil `N/2` asks, `1` bid",
        "Fulfil `1` ask, `N/2` bids",
        "Fulfil `N/2` asks, `N/2` bids",
      ];
      cols = [
        "10",
        "50",
        "100",
        "500",
        "1000",
        "10000",
      ];
    };
    let (nRows, nCols) = (schema.rows.size(), schema.cols.size());

    let envs = Array.tabulate<(asks : Types.Iter<(price : Float, volume : Nat)>, bids : Types.Iter<(price : Float, volume : Nat)>, res : ?(price : Float, volume : Nat))>(
      nRows * nCols,
      func(i) {
        let row : Nat = i % nRows;
        let col : Nat = i / nRows;

        let ?nOrders = Nat.fromText(schema.cols[col]) else Prim.trap("Cannot parse nOrders");
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
          Array.values(asks),
          Array.values(bids),
          switch (nAsks, nBids) {
            case ((0, _) or (_, 0)) null;
            case (_) ?(criticalPrice, dealVolume);
          },
        );
      },
    );

    func run(ri : Nat, ci : Nat) {
      let (asks, bids, expectedResult) = envs[ci * nRows + ri];
      let result = clearAuction(asks, bids);
      // make sure everything worked as expected
      assert result == expectedResult;
    };

    BenchV1(schema, run);
  };
};
