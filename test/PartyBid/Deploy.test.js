// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth } = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKETS, PARTY_STATUS } = require('../helpers/constants');

describe('Deploy', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      const splitRecipient = '0x0000000000000000000000000000000000000000';
      const splitBasisPoints = 0;
      const reservePrice = 1;
      const tokenId = 95;
      let factory,
        partyBid,
        partyDAOMultisig,
        marketWrapper,
        signer,
        artist,
        nftContract,
        auctionId;

      before(async () => {
        // GET RANDOM SIGNER & ARTIST
        [signer, artist] = provider.getWallets();

        // DEPLOY PARTY BID CONTRACT
        const contracts = await deployTestContractSetup(
          marketName,
          provider,
          artist,
          splitRecipient,
          splitBasisPoints,
          reservePrice,
          tokenId,
        );
        partyBid = contracts.partyBid;
        partyDAOMultisig = contracts.partyDAOMultisig;
        marketWrapper = contracts.marketWrapper;
        factory = contracts.factory;
        nftContract = contracts.nftContract;

        auctionId = await partyBid.auctionId();
      });

      it('Cannot initialize logic contract', async () => {
        // get PartyBid logic contract
        const logic = await factory.logic();
        const PartyBid = await ethers.getContractFactory('PartyBid');
        const partyBidLogic = new ethers.Contract(
          logic,
          PartyBid.interface,
          signer,
        );
        // calling initialize from external signer should not be possible
        expect(
          partyBidLogic.initialize(
            marketWrapper.address,
            nftContract.address,
            tokenId,
            auctionId,
            [splitRecipient, splitBasisPoints],
            ['0x0000000000000000000000000000000000000000', 0],
            'PartyBid Logic',
            'LOGIC',
          ),
        ).to.be.revertedWith('Party::__Party_init: only factory can init');
      });

      it('Cannot re-initialize Party contract', async () => {
        expect(
          partyBid.initialize(
            marketWrapper.address,
            nftContract.address,
            tokenId,
            auctionId,
            [splitRecipient, splitBasisPoints],
            ['0x0000000000000000000000000000000000000000', 0],
            'PartyBid',
            'PARTYYYY',
          ),
        ).to.be.revertedWith('Initializable: contract is already initialized');
      });

      it('Party Status is Active', async () => {
        const partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
      });

      it('Version is 3', async () => {
        const version = await partyBid.VERSION();
        expect(version).to.equal(3);
      });

      it('Total contributed to party is zero', async () => {
        const totalContributedToParty =
          await partyBid.totalContributedToParty();
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

      it('PartyDAO Multisig is correct', async () => {
        const multisig = await partyBid.partyDAOMultisig();
        expect(multisig).to.equal(partyDAOMultisig.address);
      });

      it('Market Wrapper is correct', async () => {
        const wrapper = await partyBid.marketWrapper();
        expect(wrapper).to.equal(marketWrapper.address);
      });

      it('Name is Parrrrti', async () => {
        const name = await partyBid.name();
        expect(name).to.equal('Parrrrti');
      });

      it('Symbol is PRTI', async () => {
        const symbol = await partyBid.symbol();
        expect(symbol).to.equal('PRTI');
      });
    });
  });
});
