// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  weiToEth,
  getTotalContributed,
  contribute,
  placeBid,
  bidThroughParty,
} = require('./helpers/utils');
const { deployTestContractSetup, getTokenVault } = require('./helpers/deploy');
const {
  PARTY_STATUS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('./helpers/constants');
const { MARKETS } = require('./helpers/constants');
const { testCases } = require('./testCases.json');

describe('Finalize', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases.map((testCase, i) => {
        describe(`Case ${i}`, async () => {
          // get test case information
          const {
            auctionReservePrice,
            contributions,
            bids,
            finalBid,
            finalFee
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
          const tokenId = 100;

          before(async () => {
            // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
            const contracts = await deployTestContractSetup(
              marketName,
              provider,
              signers[0],
              tokenId,
              auctionReservePrice,
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

          it('Is ACTIVE before Finalize', async () => {
            const partyStatus = await partyBid.partyStatus();
            expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_ACTIVE);
          });

          it('Does allow Finalize after the auction is over', async () => {
            // increase time on-chain so that auction can be finalized
            await provider.send('evm_increaseTime', [
              FOURTY_EIGHT_HOURS_IN_SECONDS,
            ]);
            await provider.send('evm_mine');

            // finalize auction
            await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');

            token = await getTokenVault(partyBid, signers[0]);
          });

          if (partyBidWins) {
            it(`Is WON after Finalize`, async () => {
              const partyStatus = await partyBid.partyStatus();
              expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_WON);
            });

            it(`Token Vault Owns the NFT`, async () => {
              const vaultAddress = await partyBid.tokenVault();
              const owner = await nftContract.ownerOf(tokenId);
              expect(owner).to.equal(vaultAddress);
            });

            it('Has correct totalSpent, totalSupply of tokens, balanceOf PartyBid tokens, and ETH balance', async () => {
              const expectedTotalSpent = finalBid[marketName] + finalFee[marketName];
              const expectedTotalSupply = expectedTotalSpent * 1000;

              const totalSpent = await partyBid.totalSpent();
              expect(totalSpent).to.equal(eth(expectedTotalSpent));

              const totalSupply = await token.totalSupply();
              expect(totalSupply).to.equal(eth(expectedTotalSupply));

              const partyBidTokenBalance = await token.balanceOf(
                partyBid.address,
              );
              expect(partyBidTokenBalance).to.equal(eth(expectedTotalSupply));

              const expectedEthBalance = totalContributed - expectedTotalSpent;
              const ethBalance = await provider.getBalance(partyBid.address);
              expect(ethBalance).to.equal(eth(expectedEthBalance));
            });

            it(`Transferred fee to multisig`, async () => {
              const balanceBeforeAsFloat = parseFloat(
                weiToEth(multisigBalanceBefore),
              );

              const multisigBalanceWithFee = eth(
                balanceBeforeAsFloat + finalFee[marketName],
              );
              const multisigBalanceAfter = await provider.getBalance(
                partyDAOMultisig.address,
              );
              expect(weiToEth(multisigBalanceAfter)).to.equal(
                weiToEth(multisigBalanceWithFee),
              );
            });
          } else {
            it(`Is LOST after Finalize`, async () => {
              const partyStatus = await partyBid.partyStatus();
              expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_LOST);
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
