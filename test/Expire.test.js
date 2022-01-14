// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, contribute, bidThroughParty, expire } = require('./helpers/utils');
const { placeBid } = require('./helpers/externalTransactions');
const { deployTestContractSetup } = require('./helpers/deploy');
const {
  MARKETS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('./helpers/constants');

describe('Expire', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      // instantiate test vars
      let partyBid, market, auctionId;
      const signers = provider.getWallets();

      before(async () => {
        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
        const contracts = await deployTestContractSetup(
          marketName,
          provider,
          signers[0],
          '0x0000000000000000000000000000000000000000', // splitRecipient
          0, // splitBasisPoints
          1, // auctionReservePrice
          95, // tokenId
        );
        partyBid = contracts.partyBid;
        market = contracts.market;

        auctionId = await partyBid.auctionId();
      });

      it('Accepts contributions before expiration', async () => {
        await expect(contribute(partyBid, signers[1], eth(0.5))).to.emit(
          partyBid,
          'Contributed',
        );
      });

      it("Can't be expired before the time specified", async () => {
        await expect(expire(partyBid, signers[1])).to.be.revertedWith(
          'PartyBid::expire: expiration time in future',
        );
      });

      it('Can still accept contributions after the expiration time', async () => {
        // increase time on-chain so that auction can be expired
        await provider.send('evm_increaseTime', [
          FOURTY_EIGHT_HOURS_IN_SECONDS,
        ]);
        await provider.send('evm_mine');
        await contribute(partyBid, signers[1], eth(0.6));
      });

      it('Can bid after the expiration time', async () => {
        await expect(bidThroughParty(partyBid, signers[1])).to.emit(
          partyBid,
          'Bid',
        );
      });

      it("Can't be expired if its winning the auction", async () => {
        await expect(expire(partyBid, signers[1])).to.be.revertedWith(
          'PartyBid::expire: currently highest bidder',
        );
      });

      it('Can be expired after the time specified', async () => {
        // Bid the auction up by someone else so we're no longer winning
        await placeBid(signers[0], market, auctionId, eth(2), marketName);

        await expect(expire(partyBid, signers[1]))
          .to.emit(partyBid, 'Finalized')
          .withArgs(2, 0, 0, eth(1.1), true);
      });

      it("Can't accept contributions after expiration", async () => {
        await expect(
          contribute(partyBid, signers[1], eth(0.5)),
        ).to.be.revertedWith('Party::contribute: party not active');
      });
    });
  });
});
