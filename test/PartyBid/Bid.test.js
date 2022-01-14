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
const { testCases } = require('./partyBidTestCases.json');

describe('Bid', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases.map((testCase, i) => {
        describe(`Case ${i}`, async () => {
          // get test case information
          const {
            auctionReservePrice,
            splitRecipient,
            splitBasisPoints,
            contributions,
            bids,
          } = testCase;
          // instantiate test vars
          let partyBid, market, auctionId;
          const signers = provider.getWallets();
          const tokenId = 95;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              splitRecipient,
              splitBasisPoints,
              auctionReservePrice,
              tokenId,
            );
            partyBid = contracts.partyBid;
            market = contracts.market;

            auctionId = await partyBid.auctionId();

            // submit contributions before bidding begins
            for (let contribution of contributions) {
              const { signerIndex, amount } = contribution;
              const signer = signers[signerIndex];
              await contribute(partyBid, signer, eth(amount));
            }
          });

          for (let bid of bids) {
            const { placedByPartyBid, amount, success } = bid;
            if (placedByPartyBid && success) {
              it('Allows PartyBid to bid', async () => {
                const { signerIndex } = contributions[0];
                await expect(
                  bidThroughParty(partyBid, signers[signerIndex]),
                ).to.emit(partyBid, 'Bid');
              });

              it('Does not allow PartyBid to bid twice', async () => {
                const { signerIndex } = contributions[0];
                await expect(
                  bidThroughParty(partyBid, signers[signerIndex]),
                ).to.be.revertedWith('PartyBid::bid: already highest bidder');
              });
            } else if (placedByPartyBid && !success) {
              it('Does not allow PartyBid to bid', async () => {
                const { signerIndex } = contributions[0];
                await expect(bidThroughParty(partyBid, signers[signerIndex])).to
                  .be.reverted;
              });
            } else if (!placedByPartyBid && success) {
              it('Accepts external bid', async () => {
                const eventName =
                  marketName == MARKET_NAMES.FOUNDATION
                    ? 'ReserveAuctionBidPlaced'
                    : 'AuctionBid';
                await expect(
                  placeBid(
                    signers[0],
                    market,
                    auctionId,
                    eth(amount),
                    marketName,
                  ),
                ).to.emit(market, eventName);
              });
            } else if (!placedByPartyBid && !success) {
              it('Does not accept external bid', async () => {
                await expect(
                  placeBid(
                    signers[0],
                    market,
                    auctionId,
                    eth(amount),
                    marketName,
                  ),
                ).to.be.reverted;
              });
            }
          }
        });
      });
    });
  });
});
