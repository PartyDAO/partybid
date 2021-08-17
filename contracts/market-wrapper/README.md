## Market Wrappers
While building `PartyBid`, we faced a challenge: each auction protocol defines a slightly different contract interface, with different logic under the hood. To enable `PartyBid` to flexibly interact with a variety of underlying auction protocols, we created the concept of a `MarketWrapper`.

## Overview
`IMarketWrapper.sol` defines a standardized interface for the minimal set of functions that `PartyBid.sol` uses to interact with a reserve auction. The NatSpec documentation on the contract explains what each function does, and where it is called within `PartyBid.sol`. 

In order to deploy a `PartyBid` to buy an NFT, the protocol auctioning the NFT must have a deployed `MarketWrapper` contract which correctly implements the auction-specific logic for each function.

`PartyBid` contracts make a few assumptions about the auctions they interact with: 
1. The auction information is stored on-chain (no off-chain order books)
2. Whichever bidder places the highest bid wins the auction (there is no selection process other than placing the highest bid)
3. Bids are placed in Ether only
4. The auction is finalized at some point (it doesn't run forever)
5. The winner of the auction is transferred the NFT when the auction is finalized

Any auction contract that adheres to these expectations can write its own `MarketWrapper` contract to become compatible with `PartyBid`.

When a `PartyBid` is deployed, it is initialized with the address of the `MarketWrapper` contract for the given auction type. This cannot be changed after deployment.

## Warning 

- Each `PartyBid` assumes that its `MarketWrapper` is correctly implemented. Mistakes in the `MarketWrapper` contract can cause problems ranging in severity from making it impossible to bid, to **locking all funds** in the `PartyBid` contract.
- Developers should exercise caution when writing new `MarketWrapper` contracts. Integrate them with the unit tests in this repo and seek ample peer review before attempting to party.
- `MarketWrapper` contracts have broad permissions to spend Ether and execute arbitrary code on behalf of the `PartyBid` contract. A malicious `MarketWrapper` can easily **steal all funds** in a `PartyBid`.
- Users should exercise extreme caution when interacting with unknown `MarketWrapper` contracts. The [partybid.app](https://www.partybid.app/) website will only support reviewed & tested `MarketWrapper` contracts.

## License
PartyBid contracts are reproduceable under the terms of [MIT license](https://en.wikipedia.org/wiki/MIT_License).

MIT © PartyDAO
