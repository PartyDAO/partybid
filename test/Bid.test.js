// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, contribute, placeBid } = require('./utils');
const { deployTestContractSetup } = require('./deploy');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('Bid', async () => {
    // get test case information
    const { auctionReservePrice, contributions, bids } = testCase;
    // instantiate test vars
    let partyBid, market, auctionId;
    const signers = provider.getWallets();
    const tokenId = 100;

    before(async () => {
      // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
      const contracts = await deployTestContractSetup(
        signers[0],
        tokenId,
        auctionReservePrice,
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
          await expect(partyBid.bid()).to.emit(partyBid, 'Bid');
        });
      } else if (placedByPartyBid && !success) {
        it('Does not allow PartyBid to bid', async () => {
          await expect(partyBid.bid()).to.be.reverted;
        });
      } else if (!placedByPartyBid && success) {
        it('Accepts external bid', async () => {
          await expect(
            placeBid(signers[0], market, auctionId, eth(amount)),
          ).to.emit(market, 'ReserveAuctionBidPlaced');
        });
      } else if (!placedByPartyBid && !success) {
        it('Does not accept external bid', async () => {
          await expect(placeBid(signers[0], market, auctionId, eth(amount))).to
            .be.reverted;
        });
      }
    }
  });
});
