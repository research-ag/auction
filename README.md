# Auction for Motoko

## Overview

A module which implements auction functionality

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
//@package auction research-ag/auction/rc-0.0.1/src
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

[Executable version of above example](https://embed.motoko.org/motoko/g/2p8EnPm2FU2kp8Bw1YaoRsUkhAsnTQYJ9peMjnvwtL5tyMVEtLGWM6id2oYYSc81hQuKxJik9TUCPCvdtGTmPUCT6piD3XPQSz2ZopR9Tru6gL76oQhgHak2sei78aVjuHbvs6qEJW34wqkzXsK6k7M3oZav9Ajan3TXpts8eug4frqdw9xCGHPrZSPyTgzqD1cVwapChDRrnrbceK47hMLHhqAJm3Svphu4RJNauoiHuikimJss8JaqLg1UKYn84mN4BVk1id5Y9bDjCc7kVKB3avf8SpXK7Y8pAxXxxkGYkQw1EdYzCh8p2mJTC6ho82Q2NB62rhqm22J4TN1aTPoMgNawTB85iJBHoGMg17o3gNQACScrRCGkq75oi59keaBdqrnncJHeiftLfWEM6jh7Z?lines=29)

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
