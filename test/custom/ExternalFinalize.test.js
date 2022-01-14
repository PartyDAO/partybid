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
  getTotalContributed,
  contribute,
  bidThroughParty,
} = require('../helpers/utils');
const {
  placeBid,
  externalFinalize,
} = require('../helpers/externalTransactions');
const { deployTestContractSetup, getTokenVault } = require('../helpers/deploy');
const {
  MARKETS,
  PARTY_STATUS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
  TOKEN_FEE_BASIS_POINTS,
  ETH_FEE_BASIS_POINTS,
  TOKEN_SCALE,
} = require('../helpers/constants');
const { testCases } = require('../partybid/partyBidTestCases.json');

describe('External Finalize', async () => {
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
            finalBid,
          } = testCase;
          // instantiate test vars
          let partyBid,
            market,
            nftContract,
            partyDAOMultisig,
            auctionId,
            multisigBalanceBefore,
            token;
          const lastBid = bids[bids.length - 1];
          const partyBidWins = lastBid.placedByPartyBid && lastBid.success;
          const signers = provider.getWallets();
          const tokenId = 95;
          // total contributed
          const totalContributed = new BigNumber(
            getTotalContributed(contributions),
          );
          // final bid
          const finBid = new BigNumber(finalBid[marketName]);
          // token fee
          const tokenFeeBps = new BigNumber(TOKEN_FEE_BASIS_POINTS);
          const tokenFeeFactor = tokenFeeBps.div(10000);
          // ETH fee
          const ethFeeBps = new BigNumber(ETH_FEE_BASIS_POINTS);
          const ethFeeFactor = ethFeeBps.div(10000);
          // token recipient
          const splitRecipientBps = new BigNumber(splitBasisPoints);
          const splitRecipientFactor = splitRecipientBps.div(10000);
          // ETH fee + total ETH spent
          const ethFee = finBid.times(ethFeeFactor);
          const expectedTotalSpent = finBid.plus(ethFee);

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

          it('Does not allow Finalize before the auction is over', async () => {
            await expect(partyBid.finalize()).to.be.reverted;
          });

          it('Is ACTIVE before external Finalize', async () => {
            const partyStatus = await partyBid.partyStatus();
            expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
          });

          it('Accepts external Finalize', async () => {
            // increase time on-chain so that auction can be finalized
            await provider.send('evm_increaseTime', [
              FOURTY_EIGHT_HOURS_IN_SECONDS,
            ]);
            await provider.send('evm_mine');

            await expect(
              externalFinalize(signers[2], market, auctionId, marketName),
            ).to.not.be.reverted;
          });

          it('Is ACTIVE before PartyBid-level Finalize', async () => {
            const partyStatus = await partyBid.partyStatus();
            expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
          });

          it('Allows PartyBid Finalize after auction-level Finalize', async () => {
            // finalize auction
            await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');

            token = await getTokenVault(partyBid, signers[0]);
          });

          it(`Doesn't accept contributions after Finalize`, async () => {
            await expect(
              contribute(partyBid, signers[0], eth(1)),
            ).to.be.revertedWith('Party::contribute: party not active');
          });

          it(`Doesn't accept bids after Finalize`, async () => {
            await expect(
              bidThroughParty(partyBid, signers[0]),
            ).to.be.revertedWith('PartyBid::bid: auction not active');
          });

          if (partyBidWins) {
            it(`Is WON after Finalize`, async () => {
              const partyStatus = await partyBid.partyStatus();
              expect(partyStatus).to.equal(PARTY_STATUS.WON);
            });

            it(`Token Vault Owns the NFT`, async () => {
              const vaultAddress = await partyBid.tokenVault();
              const owner = await nftContract.ownerOf(tokenId);
              expect(owner).to.equal(vaultAddress);
            });

            it('Has correct totalSpent', async () => {
              const totalSpent = await partyBid.totalSpent();
              expect(weiToEth(totalSpent)).to.equal(
                expectedTotalSpent.toNumber(),
              );
            });

            it('Has correct balance of tokens in PartyBid', async () => {
              const expectedPartyBidBalance =
                expectedTotalSpent.times(TOKEN_SCALE);
              const partyBidTokenBalance = await token.balanceOf(
                partyBid.address,
              );
              expect(weiToEth(partyBidTokenBalance)).to.equal(
                expectedPartyBidBalance.toNumber(),
              );
            });

            it('Transferred token fee to PartyDAO multisig', async () => {
              const totalSupply = await token.totalSupply();
              const expectedMultisigBalance = tokenFeeFactor.times(
                weiToEth(totalSupply),
              );
              const multisigBalance = await token.balanceOf(
                partyDAOMultisig.address,
              );
              expect(weiToEth(multisigBalance)).to.equal(
                expectedMultisigBalance.toNumber(),
              );
            });

            it('Transferred tokens to splitRecipient', async () => {
              const totalSupply = await token.totalSupply();
              const expectedsplitRecipientBalance = splitRecipientFactor.times(
                weiToEth(totalSupply),
              );
              const splitRecipientBalance = await token.balanceOf(
                splitRecipient,
              );
              expect(weiToEth(splitRecipientBalance)).to.equal(
                expectedsplitRecipientBalance.toNumber(),
              );
            });

            it(`Transferred ETH fee to multisig`, async () => {
              const balanceBefore = new BigNumber(
                weiToEth(multisigBalanceBefore),
              );
              const expectedBalanceAfter = balanceBefore.plus(ethFee);
              const multisigBalanceAfter = await provider.getBalance(
                partyDAOMultisig.address,
              );
              expect(weiToEth(multisigBalanceAfter)).to.equal(
                expectedBalanceAfter.toNumber(),
              );
            });

            it('Has correct balance of ETH in PartyBid', async () => {
              const expectedEthBalance =
                totalContributed.minus(expectedTotalSpent);
              const ethBalance = await provider.getBalance(partyBid.address);
              expect(weiToEth(ethBalance)).to.equal(
                expectedEthBalance.toNumber(),
              );
            });
          } else {
            it(`Is LOST after Finalize`, async () => {
              const partyStatus = await partyBid.partyStatus();
              expect(partyStatus).to.equal(PARTY_STATUS.LOST);
            });

            it(`Does not own the NFT`, async () => {
              const owner = await nftContract.ownerOf(tokenId);
              expect(owner).to.not.equal(partyBid.address);
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
          }
        });
      });
    });
  });
});
