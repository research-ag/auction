import Prim "mo:prim";
import Principal "mo:base/Principal";

import Vec "mo:vector";

import Auction "../src/lib";

func init(trustedAssetId : Nat) : (Auction.Auction, Principal) {
    let auction = Auction.Auction(
        trustedAssetId,
        {
            minAskVolume = func(_, _) = 0;
            minimumOrder = 5_000;
            performanceCounter = func(_) = 0;
        },
    );
    auction.registerAssets(trustedAssetId + 1);
    let user = Principal.fromText("rl3fy-hyflm-6r3qg-7nid5-lr6cp-ysfwh-xiqme-stgsq-bcga5-vnztf-mqe");
    (auction, user);
};

func createFt(auction : Auction.Auction) : Nat {
    let id = Vec.size(auction.assets);
    auction.registerAssets(1);
    id;
};

do {
    Prim.debugPrint("should be able to place both bid and ask on the same asset...");
    let (auction, user) = init(0);
    let ft = createFt(auction);
    auction.processAsset(ft);
    ignore auction.appendCredit(user, 0, 500_000_000);
    ignore auction.appendCredit(user, ft, 500_000_000);
    switch (auction.placeBid(user, ft, 2_000, 250)) {
        case (#ok _) ();
        case (_) assert false;
    };
    switch (auction.placeAsk(user, ft, 2_000_000, 300)) {
        case (#ok _) ();
        case (_) assert false;
    };
    assert auction.queryAssetAsks(user, ft).size() == 1;
    assert auction.queryAssetBids(user, ft).size() == 1;
};

do {
    Prim.debugPrint("should return error when placing ask with lower price than own bid price for the same asset...");
    let (auction, user) = init(0);
    let ft = createFt(auction);
    auction.processAsset(ft);
    ignore auction.appendCredit(user, 0, 500_000_000);
    ignore auction.appendCredit(user, ft, 500_000_000);
    let orderId = switch (auction.placeBid(user, ft, 2_000, 250)) {
        case (#ok id) id;
        case (_) { assert false; 0 };
    };
    switch (auction.placeAsk(user, ft, 2_000_000, 200)) {
        case (#err(#ConflictingOrder(#bid, oid))) assert oid == orderId;
        case (_) assert false;
    };
    assert auction.queryAssetBids(user, ft).size() == 1;
    assert auction.queryAssetAsks(user, ft).size() == 0;
};

do {
    Prim.debugPrint("should return error when placing bid with higher price than own ask price for the same asset...");
    let (auction, user) = init(0);
    let ft = createFt(auction);
    auction.processAsset(ft);
    ignore auction.appendCredit(user, 0, 500_000_000);
    ignore auction.appendCredit(user, ft, 500_000_000);
    let orderId = switch (auction.placeAsk(user, ft, 2_000_000, 200)) {
        case (#ok id) id;
        case (_) { assert false; 0 };
    };
    switch (auction.placeBid(user, ft, 2_000, 250)) {
        case (#err(#ConflictingOrder(#ask, oid))) assert oid == orderId;
        case (_) assert false;
    };
    assert auction.queryAssetAsks(user, ft).size() == 1;
    assert auction.queryAssetBids(user, ft).size() == 0;
};
