import Array "mo:base/Array";
import Bench "mo:bench";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

import Vec "mo:vector";

import Auction "../src";

module {
  func principalFromNat(n : Nat) : Principal {
    let blobLength = 16;
    Principal.fromBlob(
      Blob.fromArray(
        Array.tabulate<Nat8>(
          blobLength,
          func(i : Nat) : Nat8 {
            assert (i < blobLength);
            let shift : Nat = 8 * (blobLength - 1 - i);
            Nat8.fromIntWrap(n / 2 ** shift);
          },
        )
      )
    );
  };

  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Auction processing (high volumes)");
    bench.description("Process a trading pair which has N placed orders and high token precision, e.g. deal volumes have 18+ digits");

    let rows = [
      "Fulfil `0` asks, `0` bids",
      "Fulfil `1` ask, `1` bid",
      "Fulfil `N/2` asks, `1` bid",
      "Fulfil `1` ask, `N/2` bids",
      "Fulfil `N/2` asks, `N/2` bids",
    ];
    // amount of asks/bids to be fulfilled
    func get_nAsks_nBids(nOrders : Nat, ri : Nat) : (Nat, Nat) = switch (ri) {
      case (0) (0, 0);
      case (1) (1, 1);
      case (2) (nOrders / 2, 1);
      case (3) (1, nOrders / 2);
      case (4) (nOrders / 2, nOrders / 2);
      case (_) Prim.trap("Cannot determine nAsks, nBids");
    };

    let cols = [
      "10",
      "50",
      "100",
      "500",
      "1000",
      "5000",
    ];

    bench.rows(rows);
    bench.cols(cols);

    let users : [Principal] = Array.tabulate<Principal>(100_000, principalFromNat);
    let auctions : [Auction.Auction] = Array.tabulate<Auction.Auction>(
      rows.size() * cols.size(),
      func(i) {
        let a = Auction.Auction(
          0,
          {
            minimumOrder = 0;
            minAskVolume = func(_) = 0;
            performanceCounter = Prim.performanceCounter;
          },
        );
        a.registerAssets(2);
        let row : Nat = i % rows.size();
        let col : Nat = i / rows.size();

        let ?nOrders = Nat.fromText(cols[col]) else Prim.trap("Cannot parse nOrders");
        let (nAsks, nBids) = get_nAsks_nBids(nOrders, row);

        let dealVolume : Nat = 5_000_000_000_000_000_000_000;
        // bids with greater price and asks with lower price will be fulfilled
        let criticalPrice : Float = 1_000.0;

        for (i in Iter.range(1, nOrders / 2)) {
          let user = users[i - 1];
          ignore a.appendCredit(user, 0, 5_000_000_000_000_000_000_000_000_000);
          ignore a.placeBid(user, 1, dealVolume / Nat.max(nBids, 1), criticalPrice + Prim.intToFloat((nBids - i)) * 0.1);
        };
        for (i in Iter.range(1, nOrders / 2)) {
          let user = users[nOrders / 2 + i - 1];
          ignore a.appendCredit(user, 1, 5_000_000_000_000_000_000_000_000_000);
          ignore a.placeAsk(user, 1, dealVolume / Nat.max(nAsks, 1), criticalPrice - Prim.intToFloat((nAsks - i)) * 0.1);
        };
        assert Vec.get(a.stats.assets, 1).asksAmount == nOrders / 2;
        assert Vec.get(a.stats.assets, 1).bidsAmount == nOrders / 2;
        a;
      },
    );

    bench.runner(
      func(row, col) {
        let ?ci = Array.indexOf<Text>(col, cols, Text.equal) else Prim.trap("Cannot determine column: " # col);
        let ?ri = Array.indexOf<Text>(row, rows, Text.equal) else Prim.trap("Cannot determine row: " # row);
        let auction = auctions[ci * rows.size() + ri];
        auction.processAsset(1);

        // make sure everything worked as expected
        // let ?nOrders = Nat.fromText(col) else Prim.trap("Cannot parse nOrders");
        // let (nAsks, nBids) = get_nAsks_nBids(nOrders, ri);
        // assert Vec.get(auction.stats.assets, 1).bidsAmount + nBids == nOrders / 2;
        // assert Vec.get(auction.stats.assets, 1).asksAmount + nAsks == nOrders / 2;
      }
    );

    bench;
  };
};
