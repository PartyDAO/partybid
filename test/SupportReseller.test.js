// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  contribute,
  placeBid,
  supportReseller,
} = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./helpers/constants');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('SupportReseller', async () => {
    // get test case information
    const {
      auctionReservePrice,
      contributions,
      bids,
      finalBid,
      claims,
    } = testCase;
    // instantiate test vars
    let partyBid, market, partyDAOMultisig, whitelist, auctionId, quorum;
    const signers = provider.getWallets();
    const firstSigner = signers[claims[0]['signerIndex']];
    const tokenId = 100;

    before(async () => {
      // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
      const contracts = await deployTestContractSetup(
        provider,
        firstSigner,
        tokenId,
        auctionReservePrice,
      );
      partyBid = contracts.partyBid;
      market = contracts.market;
      partyDAOMultisig = contracts.partyDAOMultisig;
      whitelist = contracts.whitelist;

      const quorumPercent = await partyBid.quorumPercent();
      quorum = finalBid * 1.05 * (quorumPercent / 100);

      auctionId = await partyBid.auctionId();

      // submit contributions before bidding begins
      for (let contribution of contributions) {
        const { signerIndex, amount } = contribution;
        const signer = signers[signerIndex];
        await contribute(partyBid, signer, eth(amount));
      }

      // submit the valid bids in order
      for (let bid of bids) {
        const { placedByPartyBid, amount, success } = bid;
        if (success && placedByPartyBid) {
          await partyBid.bid();
        } else if (success && !placedByPartyBid) {
          await placeBid(firstSigner, market, auctionId, eth(amount));
        }
      }
    });

    it(`Reverts before auction has been finalized`, async () => {
      await expect(
        supportReseller(partyBid, firstSigner, partyDAOMultisig.address, '0x'),
      ).to.be.revertedWith('voting not open');

      // finalize the auction
      await provider.send('evm_increaseTime', [FOURTY_EIGHT_HOURS_IN_SECONDS]);
      await provider.send('evm_mine');
      await partyBid.finalize();
    });

    it(`Reverts before claim has been called`, async () => {
      for (let claim of claims) {
        const { signerIndex } = claim;
        const contributor = signers[signerIndex];
        await expect(
          supportReseller(
            partyBid,
            contributor,
            partyDAOMultisig.address,
            '0x',
          ),
        ).to.be.revertedWith('no voting power');

        // claim tokens before rest of tests
        await partyBid.claim(contributor.address);
      }
    });

    it(`Reverts for voter with no voting power`, async () => {
      // create random signer & fund with some gas money
      const randomSigner = provider.createEmptyWallet();
      await signers[0].sendTransaction({
        to: randomSigner.address,
        value: eth(1),
      });

      await expect(
        supportReseller(partyBid, randomSigner, partyDAOMultisig.address, '0x'),
      ).to.be.revertedWith('no voting power');
    });

    it(`Reverts for non-whitelisted reseller`, async () => {
      // create random signer & fund with some gas money
      const randomSigner = provider.createEmptyWallet();
      await expect(
        supportReseller(partyBid, firstSigner, randomSigner.address, '0x'),
      ).to.be.revertedWith('reseller !whitelisted');
    });

    it(`Accepts support for whitelisted reseller + no data`, async () => {
      // create random signer & fund with some gas money
      await expect(
        supportReseller(partyBid, firstSigner, partyDAOMultisig.address, '0x'),
      ).to.emit(partyBid, 'ResellerSupported');
      // TODO: check that votes for this reseller increased
      // TODO: check that NFT wasn't transferred (quorum shouldn't have been hit)
      // TODO: make the concept of hitting quorum more general for test cases
    });

    it(`Rejects attempt to vote twice for same reseller + no data`, async () => {
      await expect(
        supportReseller(partyBid, firstSigner, partyDAOMultisig.address, '0x'),
      ).to.be.revertedWith('already supported this reseller');
    });

    it(`Accepts vote for same reseller with different data`, async () => {
      await expect(
        supportReseller(
          partyBid,
          firstSigner,
          partyDAOMultisig.address,
          '0x1234',
        ),
      ).to.emit(partyBid, 'ResellerSupported');
    });

    it(`Rejects attempt to vote twice for same reseller + non-null data`, async () => {
      await expect(
        supportReseller(
          partyBid,
          firstSigner,
          partyDAOMultisig.address,
          '0x1234',
        ),
      ).to.be.revertedWith('already supported this reseller');
    });

    it(`Finalizes auction when quorum is hit`, async () => {
      let existingSupport = claims[0]['tokens'] / 1000;
      for (let i = 1; i < claims.length; i++) {
        if (existingSupport >= quorum) continue;
        const { signerIndex, tokens } = claims[i];
        const contributor = signers[signerIndex];

        existingSupport += tokens / 100;

        if (existingSupport >= quorum) {
          await expect(
            supportReseller(
              partyBid,
              contributor,
              partyDAOMultisig.address,
              '0x',
            ),
          ).to.emit(partyBid, 'ResellerApproved');
          // TODO: test:
          // sends NFT to address
          // calls function if data is not null
          // rejects further votes
        } else {
          await expect(
            supportReseller(
              partyBid,
              contributor,
              partyDAOMultisig.address,
              '0x',
            ),
          ).to.emit(partyBid, 'ResellerSupported');
        }
      }
    });

    // TODO: whitelist a new reseller & try supporting

    // TODO: support from a different voter
    //    Accepts address with no data for SECOND TIME from different voter
    //    Accepts address with data for SECOND TIME from different voter
  });
});
