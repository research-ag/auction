import Prim "mo:prim";
import Principal "mo:base/Principal";

import Vec "mo:vector";

import Auction "../src/lib";

func init(trustedAssetId : Nat) : (Auction.Auction, Principal) {
  let auction = Auction.Auction(
    trustedAssetId,
    {
      minAskVolume = func(_, _) = 20;
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
  Prim.debugPrint("should not be able to place ask on non-existent token...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = 123;
  switch (auction.placeAsk(user, ft, 2_000, 100_000)) {
    case (#err(#UnknownAsset)) {};
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place ask on trusted token...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  switch (auction.placeAsk(user, 0, 2_000, 100_000)) {
    case (#err(#UnknownAsset)) ();
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, 0).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place ask with non-sufficient deposit...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);

  switch (auction.placeAsk(user, ft, 500_000_001, 0)) {
    case (#err(#NoCredit)) ();
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place an ask with too low volume...");
  let (auction, user) = init(0);

  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);
  switch (auction.placeAsk(user, ft, 19, 1)) {
    case (#err(#TooLowOrder)) ();
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should be able to place a market ask...");
  let (auction, user) = init(0);

  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);
  switch (auction.placeAsk(user, ft, 19, 0)) {
    case (#ok _) ();
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, ft).size() == 1;
};

do {
  Prim.debugPrint("should be able to place an ask...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);
  switch (auction.placeAsk(user, ft, 2_000_000, 10)) {
    case (#ok _) ();
    case (_) assert false;
  };
  let asks = auction.queryAssetAsks(user, ft);
  assert asks.size() == 1;
  assert asks[0].1.assetId == ft;
  assert asks[0].1.price == 10;
  assert asks[0].1.volume == 2_000_000;
  assert auction.queryCredit(user, ft) == 498_000_000; // available deposit went down
};

do {
  Prim.debugPrint("should affect stats...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);
  ignore auction.appendCredit(user, ft, 500_000_000);

  let buyer = Principal.fromText("khppa-evswo-bmx2f-4o7bj-4t6ai-burgf-ued7b-vpduu-6fgxt-ajby6-iae");
  ignore auction.appendCredit(buyer, 0, 500_000_000);
  ignore auction.placeBid(buyer, ft, 2_000_000, 100);
  ignore auction.placeAsk(user, ft, 2_000_000, 100);

  assert Vec.get(auction.stats.assets, ft).asksAmount == 1;
  assert Vec.get(auction.stats.assets, ft).totalAskVolume == 2000000;

  auction.processAsset(ft);

  assert auction.queryAssetAsks(user, ft).size() == 0;
  assert Vec.get(auction.stats.assets, ft).asksAmount == 0;
  assert Vec.get(auction.stats.assets, ft).totalAskVolume == 0;
};

do {
  Prim.debugPrint("should be able to place few asks on the same asset...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);
  assert auction.queryCredit(user, ft) == 500_000_000;
  ignore auction.placeAsk(user, ft, 125_000_000, 125_000);
  assert auction.queryCredit(user, ft) == 375_000_000;

  switch (auction.placeAsk(user, ft, 300_000_000, 250_000)) {
    case (#ok _) ();
    case (_) assert false;
  };
  assert auction.queryCredit(user, ft) == 75_000_000;
  assert auction.queryAssetAsks(user, ft).size() == 2;
};

do {
  Prim.debugPrint("should not be able to place few asks on the same asset with the same price...");

  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);
  assert auction.queryCredit(user, ft) == 500_000_000;
  let orderId = switch (auction.placeAsk(user, ft, 125_000_000, 125_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, ft) == 375_000_000;

  switch (auction.placeAsk(user, ft, 300_000_000, 125_000)) {
    case (#err(#ConflictingOrder(#ask, oid))) assert oid == ?orderId;
    case (_) assert false;
  };
  assert auction.queryCredit(user, ft) == 375_000_000;
  assert auction.queryAssetAsks(user, ft).size() == 1;
};

do {
  Prim.debugPrint("should be able to replace an ask...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);

  let orderId = switch (auction.placeAsk(user, ft, 125_000_000, 125_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, ft) == 375_000_000;
  assert auction.queryAssetAsks(user, ft).size() == 1;

  let newOrderId = switch (auction.replaceAsk(user, orderId, 500_000_000, 250_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, ft) == 0;
  assert auction.queryAssetAsks(user, ft).size() == 1;

  switch (auction.replaceAsk(user, newOrderId, 120_000_000, 200_000)) {
    case (#ok id) {};
    case (_) assert false;
  };
  assert auction.queryCredit(user, ft) == 380_000_000;
  assert auction.queryAssetAsks(user, ft).size() == 1;
};

do {
  Prim.debugPrint("non-sufficient deposit should not cancel old ask when replacing...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  ignore auction.appendCredit(user, ft, 500_000_000);

  let orderId = switch (auction.placeAsk(user, ft, 125_000_000, 125_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, ft) == 375_000_000;
  assert auction.queryAssetAsks(user, ft).size() == 1;

  switch (auction.replaceAsk(user, orderId, 600_000_000, 50_000)) {
    case (#err(#NoCredit)) ();
    case (_) assert false;
  };

  let asks = auction.queryAssetAsks(user, ft);
  assert asks.size() == 1;
  assert asks[0].1.assetId == ft;
  assert asks[0].1.price == 125_000;
  assert asks[0].1.volume == 125_000_000;
};

do {
  Prim.debugPrint("should fulfil the only ask...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);
  ignore auction.appendCredit(user, ft, 500_000_000);

  switch (auction.placeAsk(user, ft, 100_000_000, 3)) {
    case (#ok id) {};
    case (_) assert false;
  };
  assert auction.queryAssetAsks(user, ft).size() == 1;

  let buyer = Principal.fromText("khppa-evswo-bmx2f-4o7bj-4t6ai-burgf-ued7b-vpduu-6fgxt-ajby6-iae");
  ignore auction.appendCredit(buyer, 0, 500_000_000);
  switch (auction.placeBid(buyer, ft, 100_000_000, 3)) {
    case (#ok id) {};
    case (_) assert false;
  };

  auction.processAsset(ft);

  // test that ask disappeared
  assert auction.queryAssetAsks(user, ft).size() == 0;
  // test that tokens were decremented from deposit, credit added
  assert auction.queryCredit(user, ft) == 400_000_000;
  assert auction.queryCredit(user, 0) == 300_000_000;
};

do {
  Prim.debugPrint("should sell by price priority and preserve priority...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  let buyer = Principal.fromText("khppa-evswo-bmx2f-4o7bj-4t6ai-burgf-ued7b-vpduu-6fgxt-ajby6-iae");
  ignore auction.appendCredit(buyer, 0, 5_000_000_000);
  ignore auction.placeBid(buyer, ft, 1_500_000, 500);
  assert auction.queryCredit(buyer, 0) + 1_500_000 * 500 == 5_000_000_000;

  let mediumSeller = Principal.fromText("fezva-cpps4-jvvqs-nlnm3-vafrr-d2mgi-v7lde-rog73-ry4sv-zonry-iqe");
  ignore auction.appendCredit(mediumSeller, ft, 500_000_000);
  ignore auction.placeAsk(mediumSeller, ft, 1_500_000, 200);
  assert auction.queryAssetAsks(mediumSeller, ft).size() == 1;

  let highSeller = Principal.fromText("fpmg4-qhaqp-4x26t-rihbr-bhdde-dr4oj-my7no-wg4of-2s725-zqtwa-vae");
  ignore auction.appendCredit(highSeller, ft, 500_000_000);
  ignore auction.placeAsk(highSeller, ft, 1_500_000, 500);
  assert auction.queryAssetAsks(highSeller, ft).size() == 1;

  let lowSeller = Principal.fromText("224jm-swdnn-4gymt-rtm2f-2c6dn-2w5o6-7qxte-3ndr5-budii-qfr6d-yae");
  ignore auction.appendCredit(lowSeller, ft, 500_000_000);
  ignore auction.placeAsk(lowSeller, ft, 1_500_000, 50);
  assert auction.queryAssetAsks(lowSeller, ft).size() == 1;

  let newSeller = Principal.fromText("nzps2-uu3wh-igtli-u3b5o-zonzp-42qv4-lwfdr-fxex3-jnyki-hjvnv-5ae");
  ignore auction.appendCredit(newSeller, ft, 500_000_000);

  auction.processAsset(ft);

  assert auction.queryAssetAsks(lowSeller, ft).size() == 0;
  assert auction.queryAssetAsks(mediumSeller, ft).size() == 1;
  assert auction.queryAssetAsks(highSeller, ft).size() == 1;
  // deal between buyer and lowSeller should have average price (500, 50 => 275)
  assert auction.queryCredit(lowSeller, 0) == 275 * 1_500_000;
  assert auction.queryCredit(buyer, 0) + 275 * 1_500_000 == 5_000_000_000;

  // allow one additional ask to be fulfilled
  ignore auction.placeBid(buyer, ft, 1_500_000, 500);
  auction.processAsset(ft);

  assert auction.queryAssetAsks(mediumSeller, ft).size() == 0;
  assert auction.queryAssetAsks(highSeller, ft).size() == 1;
  assert auction.queryCredit(mediumSeller, 0) == 350 * 1_500_000;

  ignore auction.placeAsk(newSeller, ft, 1_500_000, 300);
  assert auction.queryAssetAsks(newSeller, ft).size() == 1;

  // allow one additional ask to be fulfilled
  ignore auction.placeBid(buyer, ft, 1_500_000, 500);
  auction.processAsset(ft);

  // new seller joined later, but should be fulfilled since priority greater than priority of high seller
  assert auction.queryAssetAsks(newSeller, ft).size() == 0;
  assert auction.queryAssetAsks(highSeller, ft).size() == 1;
  assert auction.queryCredit(newSeller, 0) == 400 * 1_500_000;

  // allow one additional ask to be fulfilled
  ignore auction.placeBid(buyer, ft, 1_500_000, 500);
  auction.processAsset(ft);

  // finally high ask will be fulfilled
  assert auction.queryAssetAsks(highSeller, ft).size() == 0;
  assert auction.queryCredit(highSeller, 0) == 500 * 1_500_000;
};
