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
  Prim.debugPrint("should return price history with descending order...");
  let (auction, user) = init(0);
  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");

  let ft1 = createFt(auction);
  ignore auction.appendCredit(seller, ft1, 500_000_000);
  ignore auction.placeAsk(seller, ft1, 1_000, 0);

  let ft2 = createFt(auction);
  ignore auction.appendCredit(seller, ft2, 500_000_000);
  ignore auction.placeAsk(seller, ft2, 1_000, 0);

  let ft3 = createFt(auction);

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft1, 1_000, 100_000);
  ignore auction.placeBid(user, ft2, 1_000, 100_000);

  auction.processAsset(ft1);
  auction.processAsset(ft2);
  auction.processAsset(ft3);

  let history = auction.queryPriceHistory(null, 3, 0);
  assert history.size() == 3;
  assert history[0].2 == ft3;
  assert history[0].3 == 0;
  assert history[0].4 == 0;
  assert history[1].2 == ft2;
  assert history[1].3 == 1_000;
  assert history[1].4 == 100_000;
  assert history[2].2 == ft1;
  assert history[2].3 == 1_000;
  assert history[2].4 == 100_000;
};

do {
  Prim.debugPrint("should return transaction history with descending order...");
  let (auction, user) = init(0);
  let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");

  let ft1 = createFt(auction);
  ignore auction.appendCredit(seller, ft1, 500_000_000);
  ignore auction.placeAsk(seller, ft1, 1_000, 0);

  let ft2 = createFt(auction);
  ignore auction.appendCredit(seller, ft2, 500_000_000);
  ignore auction.placeAsk(seller, ft2, 1_000, 0);

  ignore auction.appendCredit(user, 0, 500_000_000);
  ignore auction.placeBid(user, ft1, 1_000, 100_000);
  ignore auction.placeBid(user, ft2, 1_000, 100_000);

  auction.processAsset(ft1);
  auction.processAsset(ft2);

  let history = auction.queryTransactionHistory(user, null, 2, 0);
  assert history[0].3 == ft2;
  assert history[1].3 == ft1;
};
