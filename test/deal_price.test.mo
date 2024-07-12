import Array "mo:base/Array";
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
  Prim.debugPrint("should use correct price when orders are completely fulfilled and there are other unfulfilled orders...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);

  ignore auction.appendCredit(user, 0, 500_000_000);

  // should be fulfilled
  switch (auction.placeBid(user, ft, 5_000_000, 1)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled, too low bid
  switch (auction.placeBid(user, ft, 5_000_000, 0.1)) {
    case (#ok _) ();
    case (_) assert false;
  };

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, ft, 500_000_000);

  // should be fulfilled
  switch (auction.placeAsk(user2, ft, 5_000_000, 0.8)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled
  switch (auction.placeAsk(user2, ft, 5_000_000, 100)) {
    case (#ok _) ();
    case (_) assert false;
  };

  auction.processAsset(ft);

  let priceHistoryItem = auction.queryPriceHistory(?ft, 1, 0)[0];
  assert priceHistoryItem.3 == 5_000_000; // volume
  assert priceHistoryItem.4 == 0.9; // average price, ask 0.8, bid 1
};

do {
  Prim.debugPrint("should use correct price when ask completely fulfilled and there are other unfulfilled orders...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);

  ignore auction.appendCredit(user, 0, 500_000_000);
  // should be fulfilled partially
  switch (auction.placeBid(user, ft, 6_009_999, 1)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled, too low bid
  switch (auction.placeBid(user, ft, 5_000_000, 0.1)) {
    case (#ok _) ();
    case (_) assert false;
  };

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, ft, 500_000_000);
  // should be fulfilled
  switch (auction.placeAsk(user2, ft, 5_000_000, 0.8)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled
  switch (auction.placeAsk(user2, ft, 5_000_000, 100)) {
    case (#ok _) ();
    case (_) assert false;
  };

  auction.processAsset(ft);

  let priceHistoryItem = auction.queryPriceHistory(?ft, 1, 0)[0];
  assert priceHistoryItem.3 == 5_000_000; // volume
  assert priceHistoryItem.4 == 0.9; // average price, ask 0.8, bid 1
};

do {
  Prim.debugPrint("should use correct price when bid completely fulfilled and there are other unfulfilled orders...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);

  ignore auction.appendCredit(user, 0, 500_000_000);
  // should be fulfilled partially
  switch (auction.placeBid(user, ft, 5_010_000, 1)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled, too low bid
  switch (auction.placeBid(user, ft, 5_000_000, 0.1)) {
    case (#ok _) ();
    case (_) assert false;
  };

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, ft, 500_000_000);
  // should be fulfilled partially
  switch (auction.placeAsk(user2, ft, 6_000_000, 0.8)) {
    case (#ok _) ();
    case (_) assert false;
  };
  // should not be fulfilled
  switch (auction.placeAsk(user2, ft, 5_000_000, 100)) {
    case (#ok _) ();
    case (_) assert false;
  };

  auction.processAsset(ft);

  let priceHistoryItem = auction.queryPriceHistory(?ft, 1, 0)[0];
  assert priceHistoryItem.3 == 5_010_000; // volume
  assert priceHistoryItem.4 == 0.9; // average price, ask 0.8, bid 1
};

do {
  Prim.debugPrint("should have correct credits flow...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  auction.processAsset(ft);

  let userExpectedCredits : [var Nat] = Array.init(2, 0);
  let user2ExpectedCredits : [var Nat] = Array.init(2, 0);
  func assertBalances(u : Principal, expectedCredits : [var Nat]) : () {
    let cr = auction.queryCredits(u);
    if (cr[0].0 == 0) {
      assert cr[0].1 == expectedCredits[0];
      assert cr[1].1 == expectedCredits[1];
    } else {
      assert cr[0].1 == expectedCredits[1];
      assert cr[1].1 == expectedCredits[0];
    };
  };
  auction.processAsset(ft);

  ignore auction.appendCredit(user, 0, 500_000_000);
  userExpectedCredits[0] += 500_000_000;

  switch (auction.placeBid(user, ft, 5_000_000, 0.1)) {
    case (#ok _) ();
    case (_) assert false;
  };
  userExpectedCredits[0] -= 500_000;

  ignore auction.appendCredit(user, ft, 500_000_000);
  userExpectedCredits[1] += 500_000_000;

  switch (auction.placeAsk(user, ft, 500_000, 26)) {
    case (#ok _) ();
    case (_) assert false;
  };
  userExpectedCredits[1] -= 500_000;

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, 0, 500_000_000);
  user2ExpectedCredits[0] += 500_000_000;
  ignore auction.appendCredit(user2, ft, 500_000_000);
  user2ExpectedCredits[1] += 500_000_000;

  switch (auction.placeAsk(user2, ft, 980_000, 0.08)) {
    case (#ok _) ();
    case (_) assert false;
  };
  user2ExpectedCredits[1] -= 980_000;

  // check credits
  assertBalances(user, userExpectedCredits);
  assertBalances(user2, user2ExpectedCredits);

  auction.processAsset(ft);

  // note: user ask was not fulfilled because has too high price
  userExpectedCredits[0] += 100_000; // bid fulfilled part funds unlocked
  userExpectedCredits[0] -= 90_200; // bid fulfilled part funds charged (lower price)
  userExpectedCredits[1] += 980_000; // credited with bought token

  // note user2 [1] balance not changed: whole volume was locked and then charged
  user2ExpectedCredits[0] += 88_200; // credited from sold token

  let priceHistoryItem = auction.queryPriceHistory(?ft, 1, 0)[0];
  assert priceHistoryItem.3 == 980_000;
  assert priceHistoryItem.4 == 0.09;

  assertBalances(user, userExpectedCredits);
  assertBalances(user2, user2ExpectedCredits);
};
