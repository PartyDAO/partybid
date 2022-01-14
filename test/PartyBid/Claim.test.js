// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
const BigNumber = require('bignumber.js');
// ============ Internal Imports ============
const {
  eth,
  weiToEth,
  getBalances,
  contribute,
  bidThroughParty,
} = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const { deployTestContractSetup, getTokenVault } = require('../helpers/deploy');
const {
  MARKETS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('../helpers/constants');
const { testCases } = require('./partyBidTestCases.json');

describe('Claim', async () => {
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
            claims,
          } = testCase;
          // instantiate test vars
          let partyBid, market, auctionId, token;
          const signers = provider.getWallets();
          const firstSigner = signers[0];
          const tokenId = 95;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              firstSigner,
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

            // submit the valid bids in order
            for (let bid of bids) {
              const { placedByPartyBid, amount, success } = bid;
              if (success && placedByPartyBid) {
                const { signerIndex } = contributions[0];
                await bidThroughParty(partyBid, signers[signerIndex]);
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
          });

          it(`Reverts before Finalize`, async () => {
            await expect(
              partyBid.claim(firstSigner.address),
            ).to.be.revertedWith('Party::claim: party not finalized');
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

          for (let claim of claims[marketName]) {
            const { signerIndex, tokens, excessEth, totalContributed } = claim;
            const contributor = signers[signerIndex];
            it('Gives the correct values for getClaimAmounts before claim is called', async () => {
              const [tokenClaimAmount, ethClaimAmount] =
                await partyBid.getClaimAmounts(contributor.address);
              expect(weiToEth(tokenClaimAmount)).to.equal(tokens);
              expect(weiToEth(ethClaimAmount)).to.equal(excessEth);
            });

            it('Gives the correct value for totalEthUsed before claim is called', async () => {
              const totalEthUsed = await partyBid.totalEthUsed(
                contributor.address,
              );
              const expectedEthUsed = new BigNumber(totalContributed).minus(
                excessEth,
              );
              expect(weiToEth(totalEthUsed)).to.equal(
                expectedEthUsed.toNumber(),
              );
            });

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
              expect(before.contributor.tokens.toNumber()).to.equal(0);

              // claim succeeds; event is emitted
              await expect(partyBid.claim(contributor.address))
                .to.emit(partyBid, 'Claimed')
                .withArgs(
                  contributor.address,
                  eth(totalContributed),
                  eth(excessEth),
                  eth(tokens),
                );

              const after = await getBalances(provider, token, accounts);

              // ETH was transferred from PartyBid to contributor
              await expect(after.partyBid.eth.toNumber()).to.equal(
                before.partyBid.eth.minus(excessEth).toNumber(),
              );

              // Tokens were transferred from PartyBid to contributor
              await expect(after.partyBid.tokens.toNumber()).to.equal(
                before.partyBid.tokens.minus(tokens).toNumber(),
              );
              await expect(after.contributor.tokens.toNumber()).to.equal(
                before.contributor.tokens.plus(tokens).toNumber(),
              );
            });

            it('Gives the same values for getClaimAmounts after claim is called', async () => {
              const [tokenClaimAmount, ethClaimAmount] =
                await partyBid.getClaimAmounts(contributor.address);
              expect(weiToEth(tokenClaimAmount)).to.equal(tokens);
              expect(weiToEth(ethClaimAmount)).to.equal(excessEth);
            });

            it('Gives the same value for totalEthUsed after claim is called', async () => {
              const totalEthUsed = await partyBid.totalEthUsed(
                contributor.address,
              );
              const expectedEthUsed = new BigNumber(totalContributed).minus(
                excessEth,
              );
              expect(weiToEth(totalEthUsed)).to.equal(
                expectedEthUsed.toNumber(),
              );
            });

            it(`Does not allow a contributor to double-claim`, async () => {
              await expect(partyBid.claim(contributor.address)).to.be.reverted;
            });
          }

          it('Gives zero for getClaimAmounts for non-contributor', async () => {
            const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
            const [tokenClaimAmount, ethClaimAmount] =
              await partyBid.getClaimAmounts(randomAddress);
            expect(tokenClaimAmount).to.equal(0);
            expect(ethClaimAmount).to.equal(0);
          });

          it('Gives the zero for totalEthUsed for non-contributor', async () => {
            const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
            const totalEthUsed = await partyBid.totalEthUsed(randomAddress);
            expect(totalEthUsed).to.equal(0);
          });

          it(`Reverts on Claim for non-contributor`, async () => {
            const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
            await expect(partyBid.claim(randomAddress)).to.be.revertedWith(
              'Party::claim: not a contributor',
            );
          });
        });
      });
    });
  });
});
