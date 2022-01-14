// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  contribute,
  getBalances,
  emergencyForceLost,
  getTotalContributed,
  bidThroughParty,
} = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKETS, PARTY_STATUS } = require('../helpers/constants');
const { testCases } = require('../partybid/partyBidTestCases.json');

describe('Emergency Force Lost', async () => {
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
          let partyBid,
            market,
            nftContract,
            partyDAOMultisig,
            auctionId,
            multisigBalanceBefore,
            token;
          const totalContributed = getTotalContributed(contributions);
          const lastBid = bids[bids.length - 1];
          const partyBidWins = lastBid.placedByPartyBid && lastBid.success;
          const signers = provider.getWallets();
          const tokenId = 95;

          // only run for tests where PartyBid loses
          if (partyBidWins) {
            return;
          }

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
              true,
            );
            partyBid = contracts.partyBid;
            market = contracts.market;
            partyDAOMultisig = contracts.partyDAOMultisig;
            nftContract = contracts.nftContract;

            auctionId = await partyBid.auctionId();

            multisigBalanceBefore = await provider.getBalance(
              partyDAOMultisig.address,
            );

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
                  signers[0],
                  market,
                  auctionId,
                  eth(amount),
                  marketName,
                );
              }
            }
          });

          it('Is ACTIVE before force lost', async () => {
            const partyStatus = await partyBid.partyStatus();
            expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
          });

          it('Does not allow non-multisig to force lost', async () => {
            await expect(emergencyForceLost(partyBid, signers[1])).to.be
              .reverted;
            await expect(emergencyForceLost(partyBid, signers[2])).to.be
              .reverted;
          });

          it('Does allow multisig to force lost, even when auction is running', async () => {
            await expect(emergencyForceLost(partyBid, signers[0])).to.not.be
              .reverted;
          });

          it('Is LOST after force lost', async () => {
            const partyStatus = await partyBid.partyStatus();
            expect(partyStatus).to.equal(PARTY_STATUS.LOST);
          });

          it('Has zero totalSpent', async () => {
            const totalSpent = await partyBid.totalSpent();
            expect(totalSpent).to.equal(0);
          });

          it('ETH balance is equal to total contributed to party', async () => {
            const partyBidBalanceAfter = await provider.getBalance(
              partyBid.address,
            );
            const totalContributedToParty =
              await partyBid.totalContributedToParty();
            expect(partyBidBalanceAfter).to.equal(totalContributedToParty);
          });

          it(`Did not transfer fee to multisig`, async () => {
            const multisigBalanceAfter = await provider.getBalance(
              partyDAOMultisig.address,
            );
            // less than because "multisig" is paying gas
            expect(parseFloat(multisigBalanceAfter)).to.be.lessThan(
              parseFloat(multisigBalanceBefore),
            );
          });

          for (let claim of claims[marketName]) {
            const { signerIndex, tokens, excessEth, totalContributed } = claim;
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

              // we expect no tokens
              expect(tokens).to.equal(0);

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

              // No Tokens were transferred from PartyBid to contributor
              await expect(after.partyBid.tokens.toNumber()).to.equal(
                before.partyBid.tokens.toNumber(),
              );
              await expect(after.contributor.tokens.toNumber()).to.equal(
                before.contributor.tokens.toNumber(),
              );
            });

            it(`Does not allow a contributor to double-claim`, async () => {
              await expect(partyBid.claim(contributor.address)).to.be.reverted;
            });
          }
        });
      });
    });
  });
});
