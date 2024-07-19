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

### Example

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
