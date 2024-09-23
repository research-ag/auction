/// A module which implements auction functionality
///
/// Copyright: 2024 MR Research AG
/// Author: Timo Hanke (timohanke)
/// Contributors: Andy Gura (AndyGura)

import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";

/// Clearing algorithm for a volume maximising uniform-price auction
///
/// This is an auction in which participants place limit orders ahead of time.
/// When the auction happens then the clearing algorithm from this package runs.
/// It finds the single price point at which the maximum volume of orders can be executed.
///
/// The application code is responsible for:
/// - Collecting orders from participants. It usually keeps orders hidden from the public until clearing happens.
/// - Sorting the orders by ascending price for ask orders and descending price for bid orders.
/// - Executing the trades at the determined price. Usually all trades get executed at the same price.
module {

  /// Orders are specified by a limit price measured in quote currency and a volume measured in base currency.
  /// The price type is generic and is required to have a comparison function `less`.
  /// Typically prices are Nat, Int or Float.
  public type Order<X> = (price : X, volume : Nat);

  public type priceResult<X> = (
    price : X,
    volume : Nat,
  );

  /// Clearing algorithm for a volume maximising uniform-price auction
  ///
  /// Suppose we have a single trading pair with base currency X and quote currency Y.
  /// The algorithm requires as input an list of bid order sorted in descending order of price and a list of ask orders sorted in ascending order of price.
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price point and the volume that can be executed at that price.
  ///
  /// In a volume maximising auction all participants get their trades executed in one event,
  /// at the same time and at the same price.
  /// Or, if their orders missed the execution price then they are not executed at all.
  ///
  /// A bid order and ask order is a pair of price and volume.
  /// The price is denominated in Y and the volume is denominated in X.
  /// The price means the price for the smallest unit of Y and is measured in the smallest unit of X.
  /// The volume is measured in the smallest unit of Y.
  ///
  /// Roughly speaking, the algorithm works as follows:
  /// We walk along ascending price on the ask side and, for each price point, accumulate the volume of all ask orders up to that price.
  /// Simultaneously, we walk along descending price on the bid side and, for each price point, accumulate the volume of all bid orders above that price.
  /// The two walks are coordinated such that the side which has the lower accumulated volume walks takes the next step, until that side's volume overtakes the accumulated volume of the side.
  /// Then the other side takes the next step, etc.
  /// When the two walks meet in price then we have found the price point at which the maximum volume can be executed.
  /// During execution all participants will get executed at the same price, regardless of their actual order price.
  /// All orders whose volume was accumulated during the walks will be executed.
  /// We say these order were "matched".
  ///
  /// The price type is generic and is provided as a type parameter.
  /// For example, it can be Float, Nat or Int.
  /// The caller has to supply a comparison function `less` for the price type.
  /// Since the algorithm uses only the comparison function `less`,
  /// it has no notion of a "valid price range".
  /// For price type Float, for example, the algorithm will work fine with negative prices, zero and infinity.
  ///
  /// The volume type is Nat.
  ///
  /// # Parameters:
  /// - `asks: Iter.Iter<Order<X>>`: An iterator over the ask orders. Must be in ascending (precisely: non-descending) order of price.
  /// - `bids: Iter.Iter<Order<X>>`: An iterator over the bid orders. Must be in descending (precisely: non-ascending) order of price.
  /// - `less: (X,X) -> Bool`: comparison function
  ///
  /// # Returns:
  /// - `price: X`: The determined execution price that maximises volume.
  /// - `volume: Nat`: The total matched volume at the determined price.
  ///
  /// First the price range is determined which maximises the matched volume.
  /// Within that range, the clearing price is determined by taking the first (i.e. highest) bid price that takes the bid side volume above the ask side volume.
  /// The returned value is `null` if no order can be matched.
  ///
  /// The algorithm accepts orders with volume 0. Such orders have no influence on the return values.
  /// The algorithm also accepts multiple orders in a row with the same price.
  public func clear<X>(
    asks : Iter.Iter<Order<X>>,
    bids : Iter.Iter<Order<X>>,
    less : (X, X) -> Bool,
  ) : ?(price : X, volume : Nat) {
    let ?first_ask = asks.next() else return null;
    var askPrice = first_ask.0;
    var bidPrice : ?X = null;
    var askVolume = first_ask.1; // (cumulative)
    var bidVolume = 0; // (cumulative)

    // loop invariant: askVolume >= bidVolume
    label L loop {
      let ?bid = bids.next() else break L;
      if (less(bid.0, askPrice)) break L;
      // optional: if (bid.1 == 0) continue L;
      bidVolume += bid.1;
      bidPrice := ?bid.0;
      label W while (askVolume < bidVolume) {
        let ?ask = asks.next() else break L;
        if (less(bid.0, ask.0)) break L;
        // optional: if (ask.1 == 0) continue W;
        askPrice := ask.0;
        askVolume += ask.1;
      };
    };

    let volume = Nat.min(askVolume, bidVolume);
    if (volume == 0) return null;
    let ?b = bidPrice else Debug.trap("should not happen");
    let price = if (bidVolume > askVolume) b else askPrice;
    return ?(price, volume);
  };

};
