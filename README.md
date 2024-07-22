[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/auction)](https://mops.one/auction)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/auction)](https://mops.one/auction/docs)

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

To play around with the matching algorithm you can use the following template and change the bids and asks:

```motoko
//@package auction research-ag/auction/tree/main/src
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import { matchOrders } "mo:auction";

let asks = [
  (50.0, 10_000),
  (60.0, 10_000),
  (70.0, 10_000),
];
let bids = [
  (70.0, 10_000),
  (60.0, 10_000),
  (50.0, 10_000),
];

matchOrders(asks.vals(), bids.vals());
```

Edit and run this template on: [embed.motoko.org](https://embed.motoko.org/motoko/g/E5Rc9eazvH6xbJsuujXCa4p8HYLvftbVPF8D7VBzYk4hy5aKUeWroPErVno3r1RTtcdtiLBQqcPtn8aLEWSSwUUnPEToMuuejwtr75X8VeE2mBQecEMa3y88aULKhjRj74ziT4SZKd1PeMcY2TuPdmAqvhK6CfrhtomddNZyNffEXFHmF53s38ctXCsXknbCcHeZ7wfPQZa3nCugqbGfz7BVkakxe9U6jxaGDHq1Zc5huKTJb9FbMw?lines=19)
 

We will analyze a few concrete examples.

#### Example 1

```motoko
let asks = [
  (50.0, 10_000),
  (60.0, 10_000),
  (70.0, 10_000),
];
let bids = [
  (70.0, 10_000),
  (60.0, 10_000),
  (50.0, 10_000),
];

let (nAsks, nBids, volume, price) = matchOrders(asks.vals(), bids.vals());
// => (2, 2, 20_000, 60.0)
```

We see three asks and bids that could individually be matched to each other at three different prices for a total volume of 30,000.
But at a single price the highest volume possible is 20,000 and it is reached at the price of 60.

#### Example 2

```motoko
let asks = [
  (0.0, 10_000),
];
let bids = [
  (100.0, 2_000),
  (90.0, 2_000),
  (80.0, 2_000),
  (70.0, 2_000),
  (60.0, 2_000), // volume of 10_000 reached here
  (50.0, 2_000),
  (40.0, 2_000),
];

let (nAsks, nBids, volume, price) = matchOrders(asks.vals(), bids.vals());
// => (1, 5, 10_000, 60.0)
```

Here, a single market sell order (ask)
is fully matched by multiple buy orders (bids).
The price is the highest price needed to fully match the sell order.

#### Example 3

```motoko
let asks = [
  (50.0, 10_000),
  (60.0, 10_000),
  (70.0, 10_000),
];
let bids = [
  (40.0, 10_000),
  (30.0, 10_000),
  (20.0, 10_000),
];

let (nAsks, nBids, volume, price) = matchOrders(asks.vals(), bids.vals());
// => (0, 0, 0, 0.0)
```

Here, 
the price of the highest bid is lower than a price of the lowest ask,
hence no volume can be exchanged.

#### Example 4

```motoko
let asks = [
  (50.0, 5_000),
  (60.0, 3_000),
  (70.0, 10_000),
];
let bids = [
  (70.0, 10_000),
  (60.0, 2_000),
];

let (nAsks, nBids, volume, price) = matchOrders(asks.vals(), bids.vals());
// => (3, 1, 10_000, 70.0)
```

Here, we see the partial fulfilment an order.
The maximum volume is 10,000 which is reached at the price of 70.0.
The total ask volume at his price is 18,000 and the total bid volume only 10,000.
Hence the first two ask order get filled and the third ask order get partially filled with 2,000 out of 10,000. 
Note that the price of last ask is used in the price calculation, regardless of how much volume is fulfilled from it.

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
