## PartyBid

PartyBid is a protocol that allows a group of internet homies to pool their funds together in order to win an NFT auction.

## PartyDAO 🥳

PartyBid is the first product developed by PartyDAO, a decentralized autonomous organization that builds and ships products. PartyDAO was [created initially](https://d.mirror.xyz/FLqkPA3iN4x-p97UhfhWwaCx8rBmVo-1yttY20oaob4) for the purpose of shipping PartyBid.
To keep up with PartyDAO, follow [@prtyDAO](https://twitter.com/prtyDAO) on Twitter and [Mirror](https://party.mirror.xyz/). Acquire 10 [$PARTY tokens](https://etherscan.io/token/0x402eb84d9cb2d6cf66bde9b46d7277d3f4a16b54?a=0x2f4bea4cb44d0956ce4980e76a20a8928e00399a) to join the DAO and party with us.

## Features

- A PartyBid contract is deployed targeting a single NFT auction
- Anyone can contribute ETH to the PartyBid while the auction is still live
- Anyone who has contributed to the PartyBid can trigger a bid on the targeted NFT auction
- After the auction closes, if the PartyBid won the NFT, the token is fractionalized; all contributors whose funds were used to win the auction are rewarded with ERC-20 tokens representing a fractionalized share of the NFT. Tokens are fractionalized using [fractional.art contracts](https://github.com/fractional-company/contracts)
- If a PartyBid wins the NFT, a 2.5 ETH fee and 2.5% of the fractional token supply is transferred to the PartyDAO multisig.

## Functions

#### PartyBidFactory

- `startParty` - deploy a PartyBid contract, specifying the NFT auction to target

#### PartyBid

- `contribute` - contribute ETH to the PartyBid
- `bid` - trigger a bid on the NFT auction. Always submits the minimum possible bid to beat the current high bidder. Reverts if the PartyBid is already the high bidder.
  `finalize` - call once after the auction closes to record and finalize the results of the auction. Deploys the fractionalized NFT vault if the PartyBid won.
- `claim` - call once per contributor after the auction closes to claim fractionalized ERC-20 tokens (for any funds that were used to win the auction) and/or excess ETH (if the auction was lost, or if the funds were not used to win the auction)
- `recover` - callable by the PartyDAO multisig to withdraw the NFT if (and only if) the auction was incorrectly marked as Lost

## Repo Layout

- `contracts/PartyBid.sol` - core logic contract for PartyBid
- `contracts/PartyBidFactory.sol` - factory contract used to deploy new PartyBid instances in a gas-efficient manner
- `contracts/market-wrapper` - MarketWrapper contracts enable PartyBid to integrate with different NFT auction implementations using a common interface
- `deploy` - Deployment script for contracts
- `test` - Hardhat tests for the core protocol
- `contracts/external` - External protocols' contracts ([Fractional Art](https://github.com/fractional-company/contracts), [Zora Auction House](https://github.com/ourzora/auction-house), [Foundation Market](https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code)), copied to this repo for use in integration testing.
- `contracts/test` - Contracts written for use in testing

## Installation

1. Install dependencies

```bash
npm i
```

2. Setup your `.env` file in order to deploy the contracts

```bash
touch .env && cat .env.example > .env
```

Then, populate the values in `.env`.

## Tests

To run the Hardhat tests, simply run

```bash
npm run test
```

## Deployment

You can find the address of deployed PartyBid Factories on each chain at `deploy/deployed-contracts`

To deploy a new PartyBid Factory, first ensure you've populated your `.env` file. The RPC endpoint should point chain you want to deploy the contracts, and the private key of the Deployer account should be funded with ETH on that chain .

Next, add a config file to `deploy/configs/[CHAIN_NAME].json` specifying the addresses of the necessary external protocols on that chain. You can use other files in that folder to see which contract addresses must be populated.

Finally, run

```bash
npm run deploy:partybid
```

## Security Review

The findings from the security review for PartyBid contracts can be found [here](https://hackmd.io/@alextowle/ryGQ4L-pd#PartyBid-Report). The security review was completed by [Alex Towle](https://twitter.com/jalex_towle).

## Credits

- [Anna Carroll](https://twitter.com/annascarroll) authored the code in this repo
- [Steve Klebanoff](https://twitter.com/steveklbnf), [Arpit Agarwal](https://twitter.com/atvanguard) and [Graeme Boy](https://twitter.com/strangechances) advised on the design of the contracts and reviewed the implementation code
- [Anish Agnihotri](https://twitter.com/_anishagnihotri) authored the original [PartyBid proof-of-concept](https://github.com/Anish-Agnihotri/partybid), and built the PartyBid frontend
- [Alex Towle](https://twitter.com/jalex_towle) completed the security review of the contracts
- [John Palmer](https://twitter.com/john_c_palmer) coordinated and product managed the project
- [Danny Aranda](https://twitter.com/daranda) managed operations, partnerships & marketing
- [fractional.art](https://fractional.art/) team created the fractionalized NFT code for the post-auction experience
- [Denis Nazarov](https://twitter.com/Iiterature) had the [original idea](https://twitter.com/Iiterature/status/1383238473767813125?s=20) for PartyBid and organized the [crowdfund](https://d.mirror.xyz/FLqkPA3iN4x-p97UhfhWwaCx8rBmVo-1yttY20oaob4) that created PartyDAO
- [Lawrence Forman](https://merklejerk.com/) provided a [thoughtful review](https://github.com/merklejerk/partybid-review/pull/1) of the PartyBid V2 contracts

## License

PartyBid contracts are reproduceable under the terms of [MIT license](https://en.wikipedia.org/wiki/MIT_License).

MIT © PartyDAO
