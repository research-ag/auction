/// Clearing algorithm for a volume maximising uniform-price auction.
///
/// This is an auction in which participants place limit orders pertaining to a specific trading pair ahead of time.
/// When the auction happens then the clearing algorithm from this package runs.
/// It finds the single price point at which the maximum volume of orders can be executed.
///
/// The application code, not this package, is responsible for:
///
/// - Collecting orders from participants. It usually keeps orders hidden from the public until clearing happens.
/// - Sorting the orders by ascending price for ask orders and descending price for bid orders.
/// - Executing the trades at the determined price.
///
/// Copyright: 2024 MR Research AG\
/// Author: Timo Hanke (timohanke)<br>  
/// Contributors: Andy Gura (AndyGura)

import Nat "mo:core/Nat";
import Runtime "mo:core/Runtime";
import Types "mo:core/Types";

module {

  /// An `Order` consists of a limit price and a volume.
  /// The volume is measured in the smallest tradeable unit of the base currency, hence is a `Nat`.
  /// The price has a generic type which in practice can be `Nat`, `Int` or `Float`.
  /// The only requirement is that the generic type has a comparison function `less`.
  /// The price is expected to encode the price of one unit of the base currency in units of the quote currency.
  /// The units used in the price definition can be arbitrarily chosen by the application.
  /// The unit of the base currency used in the price does not have to be the same as the unit used in the volume.
  public type Order<T> = (price : T, volume : Nat);

  /// The `priceResult` is the result of the clearing algorithm.
  /// It consists of a price and a volume called the "clearing price" and the "matched volume".
  /// They are in the same units as the price and volume used in `Order`.
  public type priceResult<T> = (
    price : T,
    volume : Nat,
  );

  /// The `clear` function takes the order book in the form of ordered bids and ordered asks
  /// and calculates the `priceResult`.
  ///
  /// The algorithm requires as input an iterator that returns all bid orders in descending order of price.
  /// Similarly, it requires an iterator that returns all ask orders in ascending order of price.
  /// The algorithm will then find the price point at which the maximum volume of orders can be executed.
  /// It returns that price point and the volume that can be executed at that price.
  ///
  /// In a volume maximising auction all participants get their trades executed in one event,
  /// at the same time and at the same price.
  /// Or, if their orders missed the execution price then they are not executed at all.
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
  /// The caller has to supply a comparison function `less` for the price type.
  /// Since the algorithm uses only the comparison function `less`,
  /// it has no notion of a "valid price range".
  /// For price type `Float`, for example, the algorithm will work fine with negative prices, zero and infinity.
  ///
  /// Parameters:
  ///
  /// - `asks: Types.Iter<Order<T>>`: An iterator over the ask orders. Must be in ascending (precisely: non-descending) order of price.
  /// - `bids: Types.Iter<Order<T>>`: An iterator over the bid orders. Must be in descending (precisely: non-ascending) order of price.
  /// - `less: (T,T) -> Bool`: comparison function
  ///
  /// Returns:
  ///
  /// - `price: T`: The determined execution price that maximises volume.
  /// - `volume: Nat`: The total matched volume at the determined price.
  ///
  /// First, the price range is determined which maximises the matched volume.
  /// Within that range, the clearing price is determined by taking the first (i.e. highest) bid price that takes the bid side volume above the ask side volume.
  /// The returned value is `null` if no order can be matched.
  ///
  /// The algorithm accepts orders with volume `0`. Such orders have no influence on the return values.
  /// The algorithm also accepts multiple orders in a row with the same price.
  public func clear<T>(
    asks : Types.Iter<Order<T>>,
    bids : Types.Iter<Order<T>>,
    less : (T, T) -> Bool,
  ) : ?priceResult<T> {
    let ?first_ask = asks.next() else return null;
    var askPrice = first_ask.0;
    var bidPrice : ?T = null;
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
    let ?b = bidPrice else Runtime.trap("should not happen");
    let price = if (bidVolume > askVolume) b else askPrice;
    return ?(price, volume);
  };

};
