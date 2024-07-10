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
      "Cancel N bids one by one (asc)",
      "Cancel N bids one by one (desc)",
      "Cancel all N bids at once",
      "Cancel all N bids at once, filter by asset",
      "Replace N bids one by one (asc)",
      "Replace N bids one by one (desc)",
      "Cancel all + place N bids (asc)",
      "Cancel all + place N bids (desc)",
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
    let env : [(Auction.Auction, ?Auction.CancellationAction, [Auction.PlaceOrderAction])] = Array.tabulate<(Auction.Auction, ?Auction.CancellationAction, [Auction.PlaceOrderAction])>(
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

        let createBidsActions = Array.tabulate<Auction.PlaceOrderAction>(nActions, func(i) = #bid(1, 100, 1.0 + Prim.intToFloat(i) / 1000.0));

        let (cancellation, placements) : (?Auction.CancellationAction, [Auction.PlaceOrderAction]) = switch (row) {
          case (0) (null, createBidsActions);
          case (1) (null, Array.reverse(createBidsActions));
          case (2) {
            let orderIds = switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #orders(Array.tabulate<{ #bid : Nat }>(nActions, func(i) = #bid(orderIds[i]))), []);
          };
          case (3) {
            let orderIds = switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #orders(Array.tabulate<{ #bid : Nat }>(nActions, func(i) = #bid(orderIds[nActions - 1 - i]))), []);
          };
          case (4) {
            switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) ();
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #all(null), []);
          };
          case (5) {
            switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) ();
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #all(?[1]), []);
          };
          case (6) {
            let orderIds = switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #orders(Array.tabulate<{ #bid : Nat }>(nActions, func(i) = #bid(orderIds[i]))), createBidsActions);
          };
          case (7) {
            let orderIds = switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) oids;
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #orders(Array.tabulate<{ #bid : Nat }>(nActions, func(i) = #bid(orderIds[nActions - 1 - i]))), Array.reverse(createBidsActions));
          };
          case (8) {
            switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) ();
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #all(null), createBidsActions);
          };
          case (9) {
            switch (a.manageOrders(user, null, createBidsActions)) {
              case (#ok oids) ();
              case (_) Prim.trap("Cannot prepare N set orders");
            };
            (? #all(null), Array.reverse(createBidsActions));
          };
          case (_) Prim.trap("Unknown row");
        };
        (a, cancellation, placements);
      },
    );

    bench.runner(
      func(row, col) {
        let ?ci = Array.indexOf<Text>(col, cols, Text.equal) else Prim.trap("Cannot determine column: " # col);
        let ?ri = Array.indexOf<Text>(row, rows, Text.equal) else Prim.trap("Cannot determine row: " # row);
        let (auction, cancellation, placements) = env[ci * rows.size() + ri];
        let res = auction.manageOrders(user, cancellation, placements);
        switch (res) {
          case (#ok _) ();
          case (#err _) Prim.trap("Actions failed");
        };
      }
    );

    bench;
  };
};
