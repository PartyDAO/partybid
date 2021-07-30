// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, getBalances, contribute, placeBid, claim } = require('./helpers/utils');
const { deployTestContractSetup, getTokenVault } = require('./helpers/deploy');
const {
  MARKETS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('./helpers/constants');
const { testCases } = require('./testCases.json');

describe('Claim', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases.map((testCase, i) => {
        describe(`Case ${i}`, async () => {
          // get test case information
          const { auctionReservePrice, contributions, bids, claims } = testCase;
          // instantiate test vars
          let partyBid, market, auctionId, token, gasPayingSigner;
          const signers = provider.getWallets();
          const firstSigner = signers[0];
          const tokenId = 100;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              firstSigner,
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

            // submit the valid bids in order
            for (let bid of bids) {
              const { placedByPartyBid, amount, success } = bid;
              if (success && placedByPartyBid) {
                await partyBid.bid();
              } else if (success && !placedByPartyBid) {
                await placeBid(
                  firstSigner,
                  market,
                  auctionId,
                  eth(amount),
                  marketName,
                );
              }
            }

            const wallet = ethers.Wallet.createRandom()
            gasPayingSigner = new ethers.Wallet(wallet.privateKey, provider);
            await signers[0].sendTransaction({
              to: gasPayingSigner.address,
              value: eth(100)
            });
          });

          it(`Reverts before Finalize`, async () => {
            await expect(claim(gasPayingSigner, partyBid, firstSigner.address)).to.be.revertedWith('PartyBid::claim: auction not finalized');
          });

          it('Allows Finalize', async () => {
            // increase time on-chain so that auction can be finalized
            await provider.send('evm_increaseTime', [
              FOURTY_EIGHT_HOURS_IN_SECONDS,
            ]);
            await provider.send('evm_mine');

            // finalize auction
            await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');
            token = await getTokenVault(partyBid, firstSigner);
          });

          for (let expectedClaim of claims[marketName]) {
            const { signerIndex, tokens, excessEth, totalContributed } = expectedClaim;
            const contributor = signers[signerIndex];
            it(`Allows Claim, transfers ETH and tokens to contributors after Finalize`, async () => {
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

              // signer has no PartyBid tokens before claim
              expect(before.contributor.tokens).to.equal(0);

              // claim succeeds; event is emitted
              await expect(claim(gasPayingSigner, partyBid, contributor.address))
                .to.emit(partyBid, 'Claimed')
                .withArgs(
                  contributor.address,
                  eth(totalContributed),
                  eth(excessEth),
                  eth(tokens),
                );

              const after = await getBalances(provider, token, accounts);

              // ETH was transferred from PartyBid to contributor
              await expect(after.partyBid.eth).to.equal(
                before.partyBid.eth - excessEth,
              );
              await expect(after.contributor.eth).to.equal(
                before.contributor.eth + excessEth,
              );

              // Tokens were transferred from PartyBid to contributor
              await expect(after.partyBid.tokens).to.equal(
                before.partyBid.tokens - tokens,
              );
              await expect(after.contributor.tokens).to.equal(
                before.contributor.tokens + tokens,
              );
            });

            it(`Does not allow a contributor to double-claim`, async () => {
              await expect(claim(gasPayingSigner, partyBid, contributor.address)).to.be.reverted;
            });
          }

          it(`Reverts on Claim for non-contributor`, async () => {
            const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
            await expect(claim(gasPayingSigner, partyBid, randomAddress)).to.be.revertedWith(
              'PartyBid::claim: not a contributor',
            );
          });
        });
      });
    });
  });
});
