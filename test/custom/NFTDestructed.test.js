// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, contribute, getBalances } = require('../helpers/utils');
const {
  placeBid,
  externalFinalize,
} = require('../helpers/externalTransactions');
const { deployTestContractSetup, getTokenVault } = require('../helpers/deploy');
const {
  PARTY_STATUS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
  MARKETS,
  MARKET_NAMES,
} = require('../helpers/constants');

describe('NFT Contract Self-Destructed', async () => {
  // The Nouns NFT contract cannot self-destruct
  MARKETS.filter(
    (m) => m !== MARKET_NAMES.NOUNS && m !== MARKET_NAMES.KOANS,
  ).map((marketName) => {
    describe(marketName, async () => {
      // instantiate test vars
      let partyBid,
        market,
        nftContract,
        partyDAOMultisig,
        auctionId,
        multisigBalanceBefore,
        token;
      const signers = provider.getWallets();
      const tokenId = 95;
      const reservePrice = 100;
      const totalContributed = 500;
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
        market = contracts.market;
        partyDAOMultisig = contracts.partyDAOMultisig;
        nftContract = contracts.nftContract;

        auctionId = await partyBid.auctionId();

        multisigBalanceBefore = await provider.getBalance(
          partyDAOMultisig.address,
        );

        // submit contribution before bidding begins
        await contribute(partyBid, signers[1], eth(totalContributed));

        // place external bid
        await placeBid(
          signers[0],
          market,
          auctionId,
          eth(reservePrice),
          marketName,
        );
      });

      it('Accepts external Finalize', async () => {
        // increase time on-chain so that auction can be finalized
        await provider.send('evm_increaseTime', [
          FOURTY_EIGHT_HOURS_IN_SECONDS,
        ]);
        await provider.send('evm_mine');

        await externalFinalize(signers[2], market, auctionId, marketName);
      });

      it('Can query balanceOf before self-destruct', async () => {
        // destruct the NFT contract
        await expect(nftContract.ownerOf(tokenId)).to.not.be.reverted;
      });

      it('Can self-destruct', async () => {
        // destruct the NFT contract
        await expect(nftContract.destruct()).to.not.be.reverted;
      });

      it('Can query NOT balanceOf before self-destruct', async () => {
        // destruct the NFT contract
        await expect(nftContract.ownerOf(tokenId)).to.be.reverted;
      });

      it('Is ACTIVE before PartyBid-level Finalize', async () => {
        const partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
      });

      it('Allows PartyBid Finalize after auction-level Finalize & NFT burn', async () => {
        // finalize auction
        await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');

        token = await getTokenVault(partyBid, signers[0]);
      });

      it(`Is LOST after Finalize`, async () => {
        const partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.LOST);
      });

      it('Has zero totalSpent', async () => {
        const totalSpent = await partyBid.totalSpent();
        expect(totalSpent).to.equal(0);
      });

      it(`Did not transfer fee to multisig`, async () => {
        const multisigBalanceAfter = await provider.getBalance(
          partyDAOMultisig.address,
        );
        expect(multisigBalanceAfter).to.equal(multisigBalanceBefore);
      });

      it(`Allows Claim, transfers ETH and tokens to contributors after Finalize`, async () => {
        const contributor = signers[1];
        const accounts = [
          {
            name: 'partyBid',
            address: partyBid.address,
          },
          {
            name: 'contributor',
            address: contributor.address,
          },
        ];

        const before = await getBalances(provider, token, accounts);

        // claim succeeds; event is emitted
        await expect(partyBid.claim(contributor.address))
          .to.emit(partyBid, 'Claimed')
          .withArgs(
            contributor.address,
            eth(totalContributed),
            eth(totalContributed),
            eth(0),
          );

        const after = await getBalances(provider, token, accounts);

        // ETH was transferred from PartyBid to contributor
        await expect(after.partyBid.eth.toNumber()).to.equal(
          before.partyBid.eth.minus(totalContributed).toNumber(),
        );
        await expect(after.contributor.eth.toNumber()).to.equal(
          before.contributor.eth.plus(totalContributed).toNumber(),
        );
      });
    });
  });
});
