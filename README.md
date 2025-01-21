[![mops](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/mops/auction)](https://mops.one/auction)
[![documentation](https://oknww-riaaa-aaaam-qaf6a-cai.raw.ic0.app/badge/documentation/auction)](https://mops.one/auction/docs)

# Auction for Motoko

## Overview

A module which implements auction functionality
through a volume maximising uniform-price auction.

Auction participants place limit orders during a collection period.
When the auction happens then the clearing algorithm from this package runs.
It finds the single price point at which the maximum volume of orders can be executed.
Then all participants will get their trades executed in one event, at the same time and at the same price.
During the collection period the order book is usually hidden from the public.

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
//@package auction research-ag/auction/main/src
import Float "mo:base/Float";
import Auction "mo:auction";

let asks = [
  (50.0, 100),
  (60.0, 100),
  (70.0, 100),
];
let bids = [
  (70.0, 100),
  (60.0, 100),
  (50.0, 100),
];

Auction.clear(asks.vals(), bids.vals(), Float.less);
```

Edit and run this template on: [embed.motoko.org](https://embed.motoko.org/motoko/g/QzWqprifHe2NQ7xGqbqnBoy8hqNZsnc3b2jLuzivSPwtbwac47MB7fAWU3LUs3zR3JNA4V2EXBACwEErn1w2dUb9KruaTj5KU52QnDA3PoL3bJMe4UuRdn8VyKpeVyfJizz4TY355hkTTKJZ7xkoYDuNTnVC4w7UWgJ2mzQCL4dXGGKiG3J1J4WxE7CvUx3ja7pXnaHo2Dhyg6Pjg1vhWLg7x4hSgDjd?lines=17)

We will analyze a few concrete examples.

#### Example 1

```motoko
let asks = [
  (50.0, 100),
  (60.0, 100),
  (70.0, 100),
];
let bids = [
  (70.0, 100),
  (60.0, 100),
  (50.0, 100),
];

Auction.clear(asks.vals(), bids.vals(), Float.less);
// => ?(60.0, 200)
```

We see three asks and bids that could individually be matched to each other at three different prices for a total volume of 300.
But at a single price the highest volume possible is 200 and it is reached at the price of 60.

#### Example 2

```motoko
let asks = [
  (0.0, 100),
];
let bids = [
  (100.0, 20),
  (90.0, 20),
  (80.0, 20),
  (70.0, 20),
  (60.0, 20), // volume of 100 reached here
  (50.0, 20),
  (40.0, 20),
];
Auction.clear(asks.vals(), bids.vals(), Float.less);

// => ?(50.0, 100)
```

Here, a single market sell order (ask)
is fully matched by multiple buy orders (bids).
The price is taken from where the bid volume exceeds the ask volume.

#### Example 3

```motoko
let asks = [
  (50.0, 100),
  (60.0, 100),
  (70.0, 100),
];
let bids = [
  (40.0, 100),
  (30.0, 100),
  (20.0, 100),
];
Auction.clear(asks.vals(), bids.vals(), Float.less);

// => null
```

Here, 
the price of the highest bid is lower than a price of the lowest ask,
hence no volume can be exchanged.

#### Example 4

```motoko
let asks = [
  (50.0, 50),
  (60.0, 30),
  (70.0, 100),
];
let bids = [
  (70.0, 100),
  (60.0, 20),
];

Auction.clear(asks.vals(), bids.vals(), Float.less);
// => ?(70.0, 100)
```

Here, we see the partial fulfilment an order.
The maximum volume is 100 which is reached at the price of 70.0.
The total ask volume at his price is 180 and the total bid volume only 100.
Hence the first two ask order get filled and the third ask order get partially filled with 20 out of 100. 
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
mops bench
```

## Copyright

MR Research AG, 2024
## Authors

Main authors: Timo Hanke (timohanke)  
Contributors: Andy Gura (AndyGura) 
## License

Apache-2.0
