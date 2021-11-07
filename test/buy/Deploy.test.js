// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { deployTestContractSetup } = require('./helpers/deploy');
const { eth } = require('../helpers/utils');
const { PARTY_STATUS, FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../helpers/constants');

describe('Buy: Deploy', async () => {
      const splitRecipient = "0x0000000000000000000000000000000000000000";
      const splitBasisPoints = 0;
      const maxPrice = 10;
      const tokenId = 95;
      let partyBuy, partyDAOMultisig, signer, artist;

      before(async () => {
        // GET RANDOM SIGNER & ARTIST
        [signer, artist] = provider.getWallets();

        // DEPLOY PARTY BID CONTRACT
        const contracts = await deployTestContractSetup(
          provider,
          artist,
          maxPrice,
          FOURTY_EIGHT_HOURS_IN_SECONDS,
          splitRecipient,
          splitBasisPoints,
          tokenId,
        );

        partyBuy = contracts.partyBuy;
        partyDAOMultisig = contracts.partyDAOMultisig;
      });

      it('Party Status is Active', async () => {
        const partyStatus = await partyBuy.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
      });

      it('Version is 1', async () => {
        const version = await partyBuy.VERSION();
        expect(version).to.equal(1);
      });

      it('Total spent is zero', async () => {
        const totalSpent = await partyBuy.totalSpent();
        expect(totalSpent).to.equal(eth(0));
      });

      it('Total contributed to party is zero', async () => {
        const totalContributedToParty = await partyBuy.totalContributedToParty();
        expect(totalContributedToParty).to.equal(eth(0));
      });

      it('Total Contributed is zero for random account', async () => {
        const totalContributed = await partyBuy.totalContributed(
          signer.address,
        );
        expect(totalContributed).to.equal(eth(0));
      });

      it('PartyDAO Multisig is correct', async () => {
        const multisig = await partyBuy.partyDAOMultisig();
        expect(multisig).to.equal(partyDAOMultisig.address);
      });

      it('Name is Parrrrti', async () => {
        const name = await partyBuy.name();
        expect(name).to.equal("Parrrrti");
      });

      it('Symbol is PRTI', async () => {
        const symbol = await partyBuy.symbol();
        expect(symbol).to.equal("PRTI");
      });
});
