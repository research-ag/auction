# Auction for Motoko

## Overview

A module which implements auction functionality for various trading pairs against "trusted" fungible token.

### Links

The package is published on [MOPS](https://mops.one/auction) and [GitHub](https://github.com/research-ag/auction).

The API documentation can be found [here](https://mops.one/auction/docs).

For updates, help, questions, feedback and other requests related to this package join us on:

* [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
* [Twitter](https://twitter.com/mr_research_ag)
* [Dfinity forum](https://forum.dfinity.org/)

### Motivation

### Interface

`Auction` has class-based implementation.

Stable data should be declared as
```motoko
stable var auctionDataV1 : Auction.StableDataV1 = Auction.defaultStableDataV1();
```

In `preupgrade` and `postupgrade` hooks top-level app should run `auctionDataV1 := auction.share();` and `auction.unshare(auctionDataV1);` respectively

Note: `V1` stands for first version of stable data. Later auction package will provide migration functions to carry top-level app auction stable data over to the newer version of the auction.

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
import Auction "mo:auction";
import Vec "mo:vector";

let a = Auction.Auction(
  // trusted asset id
  0,
  {
     minAskVolume = func (_) = 0;
     minimumOrder = 0;
     performanceCounter = func (_) = 0;
   }
 );
// register two assets: 0th is the trusted asset
a.registerAssets(2);

// register buyer. This user will spend trusted asset to buy asset 1
let buyer = Principal.fromText("khppa-evswo-bmx2f-4o7bj-4t6ai-burgf-ued7b-vpduu-6fgxt-ajby6-iae");
ignore a.appendCredit(buyer, 0, 1_000);

// register seller. This user has asset 1 and sells it 
let seller = Principal.fromText("ocqy6-3dphi-xgf54-vkr2e-lk4oz-3exc6-446gr-5e72g-bsdfo-4nzrm-hqe");
ignore a.appendCredit(seller, 1, 1_000);

// buyer wants to buy 10 assets with max price 50
ignore a.placeBid(buyer, 1, 10, 50.0);
// seller wants to sell 10 assets with min price 10
ignore a.placeAsk(seller, 1, 10, 10.0);

// process trading pair 0<->1
a.processAsset(1);

// check user credits, deal price was 30 (an average)
assert a.queryCredit(buyer, 0) == 700; // spent 300;
assert a.queryCredit(buyer, 1) == 10; // bought 10;

assert a.queryCredit(seller, 0) == 300; // gained 300;
assert a.queryCredit(seller, 1) == 990; // sold 10;
```

[Executable version of above example](https://embed.motoko.org/motoko/g/3iXE51p6Wej8KA2Ejkw8b4DpYt8oveQ7JvWdMdDEa5AE6UKLYEZBR4Hr8SEo7Cx9tDTxN7NHrFy83Ems8Z8JKziGZ72rpPQjrt95YDUncMhcjA7rm1148wGXqcTZnpBmuTLq35beebZb5dDEkpXngsipyqFMu9UsQhdFxhaKrqrmxjEQoVYq3zAwBDFWyMfVADbmqMvWoJo4j23yXM58nKU6qB8Gh7VaEQqU58aWdS4oEyzCoZ8ZrbBE2m6JDgaYftNTkY7EbbPGP1ykExiKFmoCqYizpj9RgWRP73vm6DsHzyXbdzz6DYwxaHSA1zBEzt3MLALQjG774MbPENg1Ep6uSMiUedDoEu6QXsboS2W4wiZhSor4Ei4JqmF3M3zPe1zL7rXH4FNj6tTBHrwJYocbLD4AYawAZ8PdhN4oKUVACCFTgKoXZrbQBpN8LLnnszo1zYsBbMcszoAhQ8icgqQ7VpvNMitUnVeXSJs656enEeyQD2MXi1voos7nFwASM7vPqrkk9WBqpeF31CZD3LRcfe2DRdYV6bS7g99nEA3aCExdZpxtBdSTtKn7dmHZJkZEfhGR6HpvWgyBN2iujnweJEB6R4164VLrfogk7kk7KiSX8B9137N2grvmgUqamKUWyBr2sHHNzDAf6UNHJMe3YGyZ5CLA3seqo3z92niGPvBLTQhTeqHDKKeCxjV9xF3iyWKPHV6PSiRsAGDYTcziDSNK39YjvxSrNdjce4Z8NzY9FhS9ejZSJmfLkyYKCY7xr6LUuuG7AqKsDdrhj6cxwtuSK5qjqSDy4a9Qkdy3ZhcmJRFMheRwdxVDSeGKyG37BZfxfZSYPKhTKwx55sTivQnPSZwmP6So1zDDerpgG97PBpW2BFNuibLT6jmhzL7nAhpc1A?lines=43)

### Build & test

We need up-to-date versions of `node`, `moc` and `mops` installed.

Then run:
```
git clone git@github.com:research-ag/auction.git
mops install
mops test
```

### Benchmark

Run
```
mops bench --replica pocket-ic
```

## Design

## Implementation notes

## Copyright

MR Research AG, 2023-2024
## Authors

Main author: Andy Gura
Contributors: Timo Hanke
## License 

Apache-2.0
