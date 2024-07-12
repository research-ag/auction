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
  Prim.debugPrint("should not be able to place bid on non-existent token...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = 123;
  let res = auction.placeBid(user, ft, 2_000, 100_000);
  switch (res) {
    case (#err(#UnknownAsset)) ();
    case (_) assert false;
  };
  assert auction.queryAssetBids(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place bid on trusted token...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = 0;
  switch (auction.placeBid(user, ft, 2_000, 100_000)) {
    case (#err(#UnknownAsset)) ();
    case (_) assert false;
  };
  assert auction.queryAssetBids(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place bid with non-sufficient deposit...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = createFt(auction);
  switch (auction.placeBid(user, ft, 2_000, 1_000_000)) {
    case (#err(#NoCredit)) ();
    case (_) assert false;
  };
  assert auction.queryAssetBids(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should not be able to place bid with too low volume...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = createFt(auction);
  switch (auction.placeBid(user, ft, 20, 100)) {
    case (#err(#TooLowOrder)) ();
    case (_) assert false;
  };
  assert auction.queryAssetBids(user, ft).size() == 0;
};

do {
  Prim.debugPrint("should be able to place a bid...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = createFt(auction);
  switch (auction.placeBid(user, ft, 2_000, 1_000)) {
    case (#ok _) ();
    case (_) assert false;
  };
  let bids = auction.queryAssetBids(user, ft);
  assert bids.size() == 1;
  assert bids[0].1.price == 1_000;
  assert bids[0].1.volume == 2_000;
  assert auction.queryCredit(user, 0) == 498_000_000;
};

do {
  Prim.debugPrint("should affect stats...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = createFt(auction);
  ignore auction.placeBid(user, ft, 2_000, 15_000);

  assert Vec.get(auction.stats.assets, ft).bidsAmount == 1;
  assert Vec.get(auction.stats.assets, ft).totalBidVolume == 2000;

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 200_000_000, 15_000);
  auction.processAsset(ft);

  assert auction.queryAssetBids(user, ft).size() == 0;
  assert Vec.get(auction.stats.assets, ft).bidsAmount == 0;
  assert Vec.get(auction.stats.assets, ft).totalBidVolume == 0;
};

do {
  Prim.debugPrint("unfulfilled bids should affect deposit...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);

  let ft = createFt(auction);
  switch (auction.placeBid(user, ft, 1_000, 400_000)) {
    case (#ok _) ();
    case (_) assert false;
  };
  switch (auction.placeBid(user, ft, 1_000, 400_000)) {
    case (#err(#NoCredit)) ();
    case (_) assert false;
  };
};

do {
  Prim.debugPrint("should be able to place few bids on the same token...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = createFt(auction);

  assert auction.queryCredit(user, 0) == 500_000_000;
  ignore auction.placeBid(user, ft, 2_000, 100_000);
  assert auction.queryCredit(user, 0) == 300_000_000;
  switch (auction.placeBid(user, ft, 2_000, 150_000)) {
    case (#ok _) ();
    case (_) assert false;
  };
  assert auction.queryCredit(user, 0) == 0;
  assert auction.queryAssetBids(user, ft).size() == 2;
};

do {
  Prim.debugPrint("should not be able to place few bids on the same token with the same price...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = createFt(auction);

  assert auction.queryCredit(user, 0) == 500_000_000;
  let orderId = switch (auction.placeBid(user, ft, 2_000, 100_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, 0) == 300_000_000;
  switch (auction.placeBid(user, ft, 2_000, 100_000)) {
    case (#err(#ConflictingOrder(#bid, oid))) assert oid == orderId;
    case (_) assert false;
  };
  assert auction.queryCredit(user, 0) == 300_000_000;
  assert auction.queryAssetBids(user, ft).size() == 1;
};

do {
  Prim.debugPrint("should be able to replace a bid...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = createFt(auction);

  let orderId = switch (auction.placeBid(user, ft, 2_000, 125_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, 0) == 250_000_000;
  assert auction.queryAssetBids(user, ft).size() == 1;

  let newOrderId = switch (auction.replaceBid(user, orderId, 2_000, 250_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, 0) == 0;
  assert auction.queryAssetBids(user, ft).size() == 1;

  switch (auction.replaceBid(user, newOrderId, 2_000, 60_000)) {
    case (#ok id) {};
    case (_) assert false;
  };
  assert auction.queryCredit(user, 0) == 380_000_000;
  assert auction.queryAssetBids(user, ft).size() == 1;
};

do {
  Prim.debugPrint("non-sufficient deposit should not cancel old bid when replacing...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = createFt(auction);

  let orderId = switch (auction.placeBid(user, ft, 2_000, 125_000)) {
    case (#ok id) id;
    case (_) { assert false; 0 };
  };
  assert auction.queryCredit(user, 0) == 250_000_000;
  assert auction.queryAssetBids(user, ft).size() == 1;

  switch (auction.replaceBid(user, orderId, 2_000_000, 250_000_000)) {
    case (#err(#NoCredit)) ();
    case (_) assert false;
  };
  assert auction.queryCredit(user, 0) == 250_000_000;
  let bids = auction.queryAssetBids(user, ft);
  assert bids.size() == 1;
  assert bids[0].0 == orderId;
  assert bids[0].1.price == 125_000;
  assert bids[0].1.volume == 2_000;
};

do {
  Prim.debugPrint("should fulfil the only bid...");
  let (auction, user) = init(0);
  ignore auction.appendCredit(user, 0, 500_000_000);
  let ft = createFt(auction);

  switch (auction.placeBid(user, ft, 2_000, 15_000)) {
    case (#ok id) {};
    case (_) assert false;
  };
  assert auction.queryAssetBids(user, ft).size() == 1;
  assert auction.queryCredit(user, 0) == 470_000_000;

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 200_000_000, 15_000);

  auction.processAsset(ft);

  // test that bid disappeared
  assert auction.queryAssetBids(user, ft).size() == 0;
  // test that tokens were decremented from deposit, credit added
  assert auction.queryCredit(user, 0) == 470_000_000;
  assert auction.queryCredit(user, ft) == 2_000;
  // check history
  let historyItem = auction.queryTransactionHistory(user, ?ft, 1, 0)[0];
  assert historyItem.1 == 0;
  assert historyItem.2 == #bid;
  assert historyItem.3 == ft;
  assert historyItem.4 == 2_000;
  assert historyItem.5 == 15_000;
};

do {
  Prim.debugPrint("should fulfil many bids at once...");
  let (auction, user) = init(0);
  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.appendCredit(user2, 0, 500_000_000);
  let ft1 = createFt(auction);
  let ft2 = createFt(auction);

  ignore auction.placeBid(user, ft1, 1_500, 100_000);
  ignore auction.placeBid(user, ft2, 1_500, 100_000);
  ignore auction.placeBid(user2, ft1, 1_500, 100_000);
  ignore auction.placeBid(user2, ft2, 1_500, 100_000);

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft1, 500_000_000);
  ignore auction.appendCredit(seller, ft2, 500_000_000);
  ignore auction.placeAsk(seller, ft1, 200_000_000, 100_000);
  ignore auction.placeAsk(seller, ft2, 200_000_000, 100_000);

  assert auction.queryAssetBids(user, ft1).size() == 1;
  assert auction.queryAssetBids(user, ft2).size() == 1;
  assert auction.queryAssetBids(user2, ft1).size() == 1;
  assert auction.queryAssetBids(user2, ft2).size() == 1;

  auction.processAsset(ft1);
  auction.processAsset(ft2);

  assert auction.queryAssetBids(user, ft1).size() == 0;
  assert auction.queryAssetBids(user, ft2).size() == 0;
  assert auction.queryAssetBids(user2, ft1).size() == 0;
  assert auction.queryAssetBids(user2, ft2).size() == 0;
};

do {
  Prim.debugPrint("should fulfil bids with the same price in order of insertion...");
  let (auction, user) = init(0);
  let ft = createFt(auction);

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 2_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft, 1_000, 100_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, 0, 500_000_000);
  ignore auction.placeBid(user2, ft, 999, 100_000);
  assert auction.queryAssetBids(user2, ft).size() == 1;

  let user3 = Principal.fromText("3ekl2-xv73q-5v4oc-u3edq-dykz6-ps2k6-jxjiu-34myc-zc6rg-ucex3-4qe");
  ignore auction.appendCredit(user3, 0, 500_000_000);
  ignore auction.placeBid(user3, ft, 1_000, 100_000);
  assert auction.queryAssetBids(user3, ft).size() == 1;

  auction.processAsset(ft);
  assert auction.queryAssetBids(user, ft).size() == 0;
  assert auction.queryAssetBids(user2, ft).size() == 0;

  assert auction.queryAssetBids(user3, ft).size() == 1;
  assert auction.queryCredit(user3, ft) == 1;
};

do {
  Prim.debugPrint("should charge lowest price...");
  let (auction, user) = init(0);
  let ft = createFt(auction);

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 3_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft, 1_500, 200_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, 0, 500_000_000);
  ignore auction.placeBid(user2, ft, 1_500, 100_000);
  assert auction.queryAssetBids(user2, ft).size() == 1;

  // should be ignored (no supply)
  let user3 = Principal.fromText("3ekl2-xv73q-5v4oc-u3edq-dykz6-ps2k6-jxjiu-34myc-zc6rg-ucex3-4qe");
  ignore auction.appendCredit(user3, 0, 500_000_000);
  ignore auction.placeBid(user3, ft, 1_500, 50_000);
  assert auction.queryAssetBids(user3, ft).size() == 1;

  auction.processAsset(ft);

  assert auction.queryAssetBids(user, ft).size() == 0;
  assert auction.queryAssetBids(user2, ft).size() == 0;
  assert auction.queryAssetBids(user3, ft).size() == 1;
  // check that price was 100 (lowest fulfilled bid) for both user and user2
  assert auction.queryCredit(user, ft) == 1_500;
  assert auction.queryCredit(user, 0) == 350_000_000;
  assert auction.queryCredit(user2, ft) == 1_500;
  assert auction.queryCredit(user2, 0) == 350_000_000;
};

do {
  Prim.debugPrint("should fulfil lowest bid partially...");
  let (auction, user) = init(0);
  let ft = createFt(auction);

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 3_500, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft, 1_500, 200_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  let user2 = Principal.fromText("tbsil-wffo6-dnxyb-b27v7-c5ghk-jsiqs-gsok7-bmtyu-w7u3b-el75k-iae");
  ignore auction.appendCredit(user2, 0, 500_000_000);
  ignore auction.placeBid(user2, ft, 1_500, 150_000);
  assert auction.queryAssetBids(user2, ft).size() == 1;

  let user3 = Principal.fromText("3ekl2-xv73q-5v4oc-u3edq-dykz6-ps2k6-jxjiu-34myc-zc6rg-ucex3-4qe");
  ignore auction.appendCredit(user3, 0, 500_000_000);
  ignore auction.placeBid(user3, ft, 1_500, 100_000);
  assert auction.queryAssetBids(user3, ft).size() == 1;

  // should be ignored (no supply)
  let user4 = Principal.fromText("4qjkc-5jhyl-gsuxu-hlkcq-p66js-epkn3-rlztj-f2exy-dgjxx-7zud4-tqe");
  ignore auction.appendCredit(user4, 0, 500_000_000);
  ignore auction.placeBid(user4, ft, 1_500, 50_000);
  assert auction.queryAssetBids(user4, ft).size() == 1;

  auction.processAsset(ft);

  // check that price was 100 (lowest partially fulfilled bid). Queried deposit grew for high bidders
  assert auction.queryCredit(user, ft) == 1_500;
  assert auction.queryCredit(user, 0) == 350_000_000;
  assert auction.queryCredit(user2, ft) == 1_500;
  assert auction.queryCredit(user2, 0) == 350_000_000;
  // user whose bid was fulfilled partially
  assert auction.queryCredit(user3, ft) == 500;
  assert auction.queryCredit(user3, 0) == 350_000_000; // 100m is locked in the bid, 50m were charged
  // check bid. Volume should be lowered by 500
  let bids = auction.queryAssetBids(user3, ft);
  assert bids.size() == 1;
  assert bids[0].1.price == 100_000;
  assert bids[0].1.volume == 1_000;
  // check that partial bid recorded in history
  let historyItem = auction.queryTransactionHistory(user3, ?ft, 1, 0)[0];
  assert historyItem.2 == #bid;
  assert historyItem.3 == ft;
  assert historyItem.4 == 500;
  assert historyItem.5 == 100_000;
};

do {
  Prim.debugPrint("should carry partially fulfilled bid over to the next session...");
  let (auction, user) = init(0);
  let ft = createFt(auction);

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft, 2_000, 100_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 1_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  auction.processAsset(ft);

  // bid is still there
  assert auction.queryAssetBids(user, ft).size() == 1;
  assert auction.queryCredit(user, 0) == 300_000_000;
  assert auction.queryCredit(user, ft) == 1_000; // was partially fulfilled

  // add another ask
  ignore auction.placeAsk(seller, ft, 1_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  auction.processAsset(ft);

  // bid should be fully fulfilled now
  assert auction.queryAssetBids(user, ft).size() == 0;
  assert auction.queryCredit(user, 0) == 300_000_000;
  assert auction.queryCredit(user, ft) == 2_000;
};

do {
  Prim.debugPrint("should fulfil bids by priority and preserve priority between bids through sessions...");
  let (auction, _) = init(0);
  let ft = createFt(auction);
  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);

  let mediumBidder = Principal.fromText("skg6a-h7fc6-ffjkm-n3hhw-uagd3-upkxs-x5zls-gjx52-tqv7s-5hi7j-nae");
  ignore auction.appendCredit(mediumBidder, 0, 500_000_000);
  ignore auction.placeBid(mediumBidder, ft, 1_500, 20_000);
  assert auction.queryAssetBids(mediumBidder, ft).size() == 1;
  let highBidder = Principal.fromText("7ddlt-3caok-vrxwe-wmyzk-vvfh6-squ7w-o5daa-7k2nu-jiewx-6y3mo-7qe");
  ignore auction.appendCredit(highBidder, 0, 500_000_000);
  ignore auction.placeBid(highBidder, ft, 1_500, 50_000);
  assert auction.queryAssetBids(highBidder, ft).size() == 1;
  let lowBidder = Principal.fromText("pcrzk-kgmfw-7gaj5-ev6i3-2kpmo-mafjf-extsq-csmk6-cabdq-xjgvw-nae");
  ignore auction.appendCredit(lowBidder, 0, 500_000_000);
  ignore auction.placeBid(lowBidder, ft, 1_500, 5_000);
  assert auction.queryAssetBids(lowBidder, ft).size() == 1;

  // allow one additional bid next session
  ignore auction.placeAsk(seller, ft, 1_500, 0);
  auction.processAsset(ft);
  assert auction.queryAssetBids(highBidder, ft).size() == 0;
  assert auction.queryAssetBids(mediumBidder, ft).size() == 1;
  assert auction.queryAssetBids(lowBidder, ft).size() == 1;

  // allow one additional bid next session
  ignore auction.placeAsk(seller, ft, 1_500, 0);
  auction.processAsset(ft);
  assert auction.queryAssetBids(mediumBidder, ft).size() == 0;
  assert auction.queryAssetBids(lowBidder, ft).size() == 1;

  let newBidder = Principal.fromText("w4lvw-dxncd-7klkg-go27e-gqfza-4vufd-k66s4-dqi2e-nen6j-3ro2z-7qe");
  ignore auction.appendCredit(newBidder, 0, 500_000_000);
  ignore auction.placeBid(newBidder, ft, 1_500, 20_000);
  assert auction.queryAssetBids(newBidder, ft).size() == 1;

  // allow one additional bid next session
  ignore auction.placeAsk(seller, ft, 1_500, 0);
  auction.processAsset(ft);
  // new bidder joined later, but should be fulfilled since priority greater than priority of low bid
  assert auction.queryAssetBids(newBidder, ft).size() == 0;
  assert auction.queryAssetBids(lowBidder, ft).size() == 1;

  ignore auction.placeAsk(seller, ft, 1_500, 0);
  auction.processAsset(ft);
  // finally low bid will be fulfilled
  assert auction.queryAssetBids(lowBidder, ft).size() == 0;
};

do {
  Prim.debugPrint("should be able to place another bid for next auction session...");
  let (auction, user) = init(0);
  let ft = createFt(auction);
  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
  ignore auction.appendCredit(seller, ft, 500_000_000);
  ignore auction.placeAsk(seller, ft, 1_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft, 1_000, 100_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  auction.processAsset(ft);

  assert auction.queryAssetAsks(seller, ft).size() == 0;
  assert auction.queryAssetBids(user, ft).size() == 0;

  ignore auction.placeAsk(seller, ft, 1_000, 0);
  assert auction.queryAssetAsks(seller, ft).size() == 1;
  ignore auction.placeBid(user, ft, 1_000, 100_000);
  assert auction.queryAssetBids(user, ft).size() == 1;

  auction.processAsset(ft);

  assert auction.queryAssetAsks(seller, ft).size() == 0;
  assert auction.queryAssetBids(user, ft).size() == 0;

  assert auction.queryCredit(user, ft) == 2_000;
};
