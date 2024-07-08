import Array "mo:base/Array";
import Bench "mo:bench";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Text "mo:base/Text";

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

    bench.name("Managing orders");
    bench.description("Place/cancel many asks/bids in one atomic call. In this test asset does not have any additional orders set");

    let rows = [
      "Place N bids (asc)",
      "Place N bids (desc)",
      "Cancel N bids (asc)",
      "Cancel N bids (desc)",
      "Replace N bids one by one (asc)",
      "Replace N bids one by one (desc)",
    ];

    let cols = [
      "10",
      "50",
      "100",
      "500",
      "1000",
    ];

    bench.rows(rows);
    bench.cols(cols);

    let user : Principal = principalFromNat(789);
    let env : [(Auction.Auction, [Auction.ManageOrderAction])] = Array.tabulate<(Auction.Auction, [Auction.ManageOrderAction])>(
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

        let ?nActions = Nat.fromText(cols[col]) else Prim.trap("Cannot parse nOrders");
        ignore a.appendCredit(user, 0, 5_000_000_000_000);

        let createBidsActions = Array.tabulate<Auction.ManageOrderAction>(nActions, func(i) = #placeBid(1, 100, 1.0 + Prim.intToFloat(i) / 1000.0));

        let actions = switch (row) {
          case (0) createBidsActions;
          case (1) Array.reverse(createBidsActions);
          case (2) {
            let orderIds = switch (a.manageOrders(user, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            Array.tabulate<Auction.ManageOrderAction>(nActions, func(i) = #cancelBid(orderIds[i]));
          };
          case (3) {
            let orderIds = switch (a.manageOrders(user, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            Array.tabulate<Auction.ManageOrderAction>(nActions, func(i) = #cancelBid(orderIds[nActions - 1 - i]));
          };
          case (4) {
            let orderIds = switch (a.manageOrders(user, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            Array.tabulate<Auction.ManageOrderAction>(
              nActions * 2,
              func(i) = switch (i % 2) {
                case (0) #cancelBid(orderIds[i / 2]);
                case (_) createBidsActions[i / 2];
              },
            );
          };
          case (5) {
            let orderIds = switch (a.manageOrders(user, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            Array.tabulate<Auction.ManageOrderAction>(
              nActions * 2,
              func(i) = switch (i % 2) {
                case (0) #cancelBid(nActions - 1 - orderIds[i / 2]);
                case (_) createBidsActions[nActions - 1 - i / 2];
              },
            );
          };
          case (_) Prim.trap("Unknown row");
        };
        (a, actions);
      },
    );

    bench.runner(
      func(row, col) {
        let ?ci = Array.indexOf<Text>(col, cols, Text.equal) else Prim.trap("Cannot determine column: " # col);
        let ?ri = Array.indexOf<Text>(row, rows, Text.equal) else Prim.trap("Cannot determine row: " # row);
        let (auction, actions) = env[ci * rows.size() + ri];
        let res = auction.manageOrders(user, actions);
        switch (res) {
          case (#ok _) ();
          case (#err _) Prim.trap("Actions failed");
        };
      }
    );

    bench;
  };
};
