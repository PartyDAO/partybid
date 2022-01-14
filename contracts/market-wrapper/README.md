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

## How to Buidl

0. Gather supporting resources

   - Use previous PRs adding Market Wrappers as a reference / guide throughout this process. See: [PR adding Nouns Market Wrapper](https://github.com/PartyDAO/partybid/pull/43)
   - [Join the PartyDAO Discord](https://discord.gg/uMJxGZ6emD) and introduce yourself in the `#dev` channel.
   - The PartyDAO team is happy to help and answer questions, but please read the documentation first (including the Overview and Warning sections).

1. Write the MarketWrapper contract

   - inherit from `IMarketWrapper.sol` and implement each function
   - read the documentation in `IMarketWrapper.sol` **carefully** to implement each function correctly
   - you can look at other MarketWrappers in the `contracts/market-wrapper` folder as examples
   - think carefully about edge cases and special dynamics of the market contract

2. Integrate with PartyBid unit tests

   - Add the Market contracts to the `contracts/external` folder, so they can be deployed in the testing setup. If your Market is targeting a specific custom NFT, also add the NFT contract(s).
   - In `test/helpers/constants.js`, add the name of your market to `MARKET_NAMES`
   - In `test/helpers/deploy.js`, add code to `deployTestContractSetup` to deploy and configure the Market contracts, start an auction, and deploy the new Market Wrapper contract. If applicable, also write code to deploy and configure the custom NFT contract(s).
   - In `test/helpers/externalTransactions.js`, add the Market's data encoding in each of the functions.
   - Finally, in `test/testCases.json`, add the expected `finalBid`, `finalFee`, and `claims`, which is based on minimum increase between bids on the Market. Zora and Nouns have 5% increase between bids, Foundation has 10%. If your market has either of these, you can copy their numbers for your market. If not, you will need to calculate them for your market. (Note: we plan to refactor this later.)
   - If applicable, write custom unit tests for special dynamics of the market contract.
   - Run the unit tests and ensure they are all passing with your Market Wrapper

3. Get Peer Reviews

   - At this point, you should have an implemented MarketWrapper contract and fully passing unit tests.
   - Get in touch with the PartyDAO team to kick off the process of reviewing your PR.
   - We will likely ask you to secure peer reviews from at least 1 external experienced smart contract developer in addition to reviews by the PartyDAO team.

4. Deploy to Mainnet & Fork Test

   - Deploy the MarketWrapper contract to mainnet & verify the source code
   - See `deploy/index.js` and `deploy/verify.js` for example scripts
   - Ensure the contract addresses are added to `deploy/deployed-contracts` for each network
   - PartyDAO Team will run fork tests against the deployed contract to double check that it has been configured properly

5. Get Added to PartyBid UI & Start Partying

   - Work with the PartyDAO team to get the Market's NFT metadata & the deployed Market Wrapper contract added to partybid.app
   - Once it's live on the frontend, you can start to party!

## Warning

- Each `PartyBid` assumes that its `MarketWrapper` is correctly implemented. Mistakes in the `MarketWrapper` contract can cause problems ranging in severity from making it impossible to bid, to **locking all funds** in the `PartyBid` contract.
- Developers should exercise caution when writing new `MarketWrapper` contracts. Integrate them with the unit tests in this repo and seek ample peer review before attempting to party.
- `MarketWrapper` contracts have broad permissions to spend Ether and execute arbitrary code on behalf of the `PartyBid` contract. A malicious `MarketWrapper` can easily **steal all funds** in a `PartyBid`.
- Users should exercise extreme caution when interacting with unknown `MarketWrapper` contracts. The [partybid.app](https://www.partybid.app/) website will only support reviewed & tested `MarketWrapper` contracts.

## License

PartyBid contracts are reproduceable under the terms of [MIT license](https://en.wikipedia.org/wiki/MIT_License).

MIT © PartyDAO
