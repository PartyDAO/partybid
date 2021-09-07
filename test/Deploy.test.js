// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth } = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const { PARTY_STATUS, MARKETS } = require('./helpers/constants');

describe('Deploy', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      const tokenRecipient = "0x0000000000000000000000000000000000000000";
      const tokenRecipientBasisPoints = 0;
      const reservePrice = 1;
      const tokenId = 95;
      let partyBid, signer, artist;

      before(async () => {
        // GET RANDOM SIGNER & ARTIST
        [signer, artist] = provider.getWallets();

        // DEPLOY PARTY BID CONTRACT
        const contracts = await deployTestContractSetup(
          marketName,
          provider,
          artist,
          tokenRecipient,
          tokenRecipientBasisPoints,
          reservePrice,
          tokenId,
        );
        partyBid = contracts.partyBid;
      });

      it('Party Status is Active', async () => {
        const partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_ACTIVE);
      });

      it('Version is 2', async () => {
        const version = await partyBid.VERSION();
        expect(version).to.equal(2);
      });

      it('Total contributed to party is zero', async () => {
        const totalContributedToParty = await partyBid.totalContributedToParty();
        expect(totalContributedToParty).to.equal(eth(0));
      });

      it('Highest bid is zero', async () => {
        const highestBid = await partyBid.highestBid();
        expect(highestBid).to.equal(eth(0));
      });

      it('Total spent is zero', async () => {
        const totalSpent = await partyBid.totalSpent();
        expect(totalSpent).to.equal(eth(0));
      });

      it('Total Contributed is zero for random account', async () => {
        const totalContributed = await partyBid.totalContributed(
          signer.address,
        );
        expect(totalContributed).to.equal(eth(0));
      });
    });
  });
});
