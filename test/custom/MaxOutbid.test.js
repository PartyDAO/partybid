// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, contribute, bidThroughParty } = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKETS, MARKET_NAMES } = require('../helpers/constants');

const testCases = [
  {
    reserve: 500,
    balance: {
      [MARKET_NAMES.ZORA]: 551.25,
      [MARKET_NAMES.FOUNDATION]: 577.5,
      [MARKET_NAMES.NOUNS]: 551.25,
      [MARKET_NAMES.FRACTIONAL]: 551.25,
    },
  },
  {
    reserve: 1,
    balance: {
      [MARKET_NAMES.ZORA]: 1.1025,
      [MARKET_NAMES.FOUNDATION]: 1.155,
      [MARKET_NAMES.NOUNS]: 1.1025,
      [MARKET_NAMES.FRACTIONAL]: 1.1025,
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

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              tokenId,
              reservePrice,
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

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              tokenId,
              reservePrice,
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
