# Auction changelog

## 2.0.0

* Improved algorithm 30% faster
* Two functions, one for price only, one for price range
* Generic price type as type parameter (e.g. Nat, Int, Float)
* No rejection of negative prices or infinity
* Handle volume 0 orders
* Bumped moc dependencies to 0.12.1

## 1.0.0

* Remove market orders
* Limit return value to only price and volume
* Refactor code for readability 
* Trap on order price of 0 and infinity

## 0.0.1

* Initial version
