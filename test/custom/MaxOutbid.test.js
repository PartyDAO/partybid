// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
const BigNumber = require('bignumber.js');
// ============ Internal Imports ============
const {
  eth,
  weiToEth,
  contribute,
  bidThroughParty,
} = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const { deployTestContractSetup } = require('../helpers/deploy');
const {
  MARKETS,
  MARKET_NAMES,
  ETH_FEE_BASIS_POINTS,
} = require('../helpers/constants');

const testCases = [
  {
    reserve: 250,
    balance: {
      [MARKET_NAMES.ZORA]: 269.0625,
      [MARKET_NAMES.FOUNDATION]: 281.875,
      [MARKET_NAMES.NOUNS]: 269.0625,
      [MARKET_NAMES.KOANS]: 269.0625,
    },
  },
  {
    reserve: 1,
    balance: {
      [MARKET_NAMES.ZORA]: 1.07625,
      [MARKET_NAMES.FOUNDATION]: 1.1275,
      [MARKET_NAMES.NOUNS]: 1.07625,
      [MARKET_NAMES.KOANS]: 1.07625,
    },
  },
];

describe('Maximum Outbid', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases.map((testCase, i) => {
        // get test case information
        const { reserve, balance } = testCase;
        describe(`Case ${i}`, async () => {
          // instantiate test vars
          let partyBid;
          const signers = provider.getWallets();
          const tokenId = 95;
          const reservePrice = reserve;
          const splitRecipient = '0x0000000000000000000000000000000000000000';
          const splitBasisPoints = 0;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              splitRecipient,
              splitBasisPoints,
              reservePrice,
              tokenId,
            );
            partyBid = contracts.partyBid;
            const market = contracts.market;
            const auctionId = await partyBid.auctionId();

            // contribute balance to PartyBid
            await contribute(partyBid, signers[0], eth(balance[marketName]));

            // submit first bid from external account
            await placeBid(
              signers[0],
              market,
              auctionId,
              eth(reservePrice),
              marketName,
            );
          });

          it(`Gives correct value for getMaximumBid`, async () => {
            const bal = new BigNumber(balance[marketName]);
            const ethFeeBps = new BigNumber(ETH_FEE_BASIS_POINTS);
            const ethFeeFactor = ethFeeBps.div(10000).plus(1);
            const maxBid = await partyBid.getMaximumBid();
            await expect(weiToEth(maxBid)).to.equal(
              bal.dividedBy(ethFeeFactor).toNumber(),
            );
          });

          it(`Allows outbidding a ${reservePrice} ETH bid`, async () => {
            await expect(bidThroughParty(partyBid, signers[0])).to.emit(
              partyBid,
              'Bid',
            );
          });
        });
      });
    });
  });
});

describe('Failed Maximum Outbid', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases.map((testCase, i) => {
        // get test case information
        const { reserve, balance } = testCase;
        describe(`Case ${i}`, async () => {
          // instantiate test vars
          let partyBid;
          const signers = provider.getWallets();
          const tokenId = 95;
          const reservePrice = reserve + 0.000000000001;
          const splitRecipient = '0x0000000000000000000000000000000000000000';
          const splitBasisPoints = 0;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              splitRecipient,
              splitBasisPoints,
              reservePrice,
              tokenId,
            );
            partyBid = contracts.partyBid;
            const market = contracts.market;
            const auctionId = await partyBid.auctionId();

            // contribute balance to PartyBid
            await contribute(partyBid, signers[0], eth(balance[marketName]));

            // submit first bid from external account
            await placeBid(
              signers[0],
              market,
              auctionId,
              eth(reservePrice),
              marketName,
            );
          });

          it(`Does not allow outbidding a ${reservePrice} ETH bid`, async () => {
            await expect(bidThroughParty(partyBid, signers[0])).to.be.reverted;
          });
        });
      });
    });
  });
});
