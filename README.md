# Auction for Motoko

## Overview

A module which implements auction functionality
with a volume maximising single-price auction.

Auction participants place limit orders or market orders ahead of time
and the order book is usually hidden from the public.
When the auction happens then the matching algorithm from this package runs.
It finds the single price point at which the maximum volume of orders can be executed.
Then all participants will get their trades executed in one event, at the same time and at the same price.

### Links

The package is published on [MOPS](https://mops.one/auction) and [GitHub](https://github.com/research-ag/auction).

API documentation: [here on Mops](https://mops.one/auction/docs)

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

## Usage

### Install with mops

You need `mops` installed. In your project directory run:
```
mops add auction
```

In the Motoko source file import the package as:
```
import Auction "mo:auction";
```

### Examples

```motoko
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import { matchOrders } "mo:auction";

let asks = Iter.fromArray<(Float, Nat)>([
  (50.0, 10_000),
  (60.0, 10_000),
  (70.0, 10_000),
]);
let bids = Iter.fromArray<(Float, Nat)>([
  (70.0, 10_000),
  (60.0, 10_000),
  (50.0, 10_000),
]);

let (nAsks, nBids, volume, price) = matchOrders(asks, bids);

assert nAsks == 2;
assert nBids == 2;
assert volume == 20_000;
assert price == 60.0;

(nAsks, nBids, volume, price);
```

[Executable version of above example](https://embed.motoko.org/motoko/g/dUik8CbSbJXFuwUGR8DsHmA5ruvR25cqu8cV3Y47Yufq4PqdNJwv2Y4YrV4RfaQzoEG4usqbGLuWW2e5zbc8NB721o3sRKkkmeLbpraJQm3k1Hvwfcq3wWZY3B2crSwYtE4VePuUJvzQv9Fg1yXRMiuk3DxUh65hn1RXCL71GfecFi8sjL22shfbx6yqJSw5WUs1qr9CRMeNJanMmoobuwdgAsDAY3KNxXjKyPHWNnhpiLt356zCTyqm5uhBrE1vAsgQBHAEPHXv5ujz9NJkeCvtUeySxxKJBfzKtfV5yvJGgSTBbk7hVnG3JFk4wVatAfZTmVKD12W1RVZCnMWHj5NkFVZ1n9c33d6?lines=26)


```motoko
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import { matchOrders } "mo:auction";

let asks = Iter.fromArray<(Float, Nat)>([
  (0.0, 10000),
]);
let bids = Iter.fromArray<(Float, Nat)>([
  (100.0, 2000),
  (90.0, 2000),
  (80.0, 2000),
  (70.0, 2000),
  (60.0, 2000),
  // do not filfil: out of volume
  (50.0, 2000),
  (40.0, 2000),
]);

let (nAsks, nBids, volume, price) = matchOrders(asks, bids);

assert nAsks == 1;
assert nBids == 5;
assert volume == 10_000;
assert price == 60.0;

(nAsks, nBids, volume, price);
```

[Executable version of above example](https://embed.motoko.org/motoko/g/2Dugb2J1Nhm62uibeFHhf7gxxVFq3nHa9A9EBdWppt9gdGCKEjzGRD2wbD18gYjEbubzcwVcTHH6zPnuuYj2g2MBT845gVeEZs3ZSvczGcfHKJTALNFJ888TWTrKgq532W1AZW24WC1fMfb3fcD9sXLbyKyFsSzH9HVxHj3D193t2dZJsDxuKQ745Yzr26Q82rPVWWLMpWKvGWQZ5HJdLv9xQ3ee94kcryXppTxbrjNyT3pMyTqduK7wHwBT3iETNTtf59WbQm1NsP6Lbz8psMefKX3uvUB2iFkxnj9tKKXc2nqLvT4FdN3y77Vxs6FNEv6G41TLL31iLwjFcaBmgTxZB2xLoBbHdUG9zSYxsyeLEAV8tSXT4ppC2hza4AJD4NnKMW1HVKQhtrDnEeekK?lines=29)

### Build & test

Run:
```
git clone git@github.com:research-ag/auction.git
cd auction
mops test
```

## Benchmarks

### Mops benchmark

Run
```
mops bench --replica pocket-ic
```

## Copyright

MR Research AG, 2023-24
## Authors

Main author: Andy Gura (AndyGura)

Contributors: Timo Hanke (timohanke)
## License

Apache-2.0
