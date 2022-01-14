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
  initExpectedTotalContributed,
  contribute,
  getBalances,
  bidThroughParty,
} = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const {
  deployTestContractSetup,
  deploy,
  getTokenVault,
} = require('../helpers/deploy');
const {
  MARKETS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('../helpers/constants');
const { testCases } = require('../partybid/partyBidTestCases.json');

// indexes of test cases with one contribution per signer
const compatibleTestCases = [2, 3, 4, 7];

describe('TokenGating', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      testCases
        .filter((testCase, i) => compatibleTestCases.includes(i))
        .map((testCase, i) => {
          describe(`Case ${i}`, async () => {
            // get test case information
            let partyBid,
              signer,
              nftContract,
              gatedERC20,
              tokenVault,
              market,
              auctionId;
            const {
              splitRecipient,
              splitBasisPoints,
              contributions,
              auctionReservePrice,
              bids,
              claims,
            } = testCase;
            const tokenId = 95;
            const signers = provider.getWallets();
            let expectedTotalContributedToParty = 0;
            const expectedTotalContributed =
              initExpectedTotalContributed(signers);

            before(async () => {
              // GET RANDOM SIGNER & ARTIST
              [signer] = provider.getWallets();

              gatedERC20 = await deploy('EtherToken');

              // DEPLOY PARTY BID CONTRACT
              const contracts = await deployTestContractSetup(
                marketName,
                provider,
                signer,
                splitRecipient,
                splitBasisPoints,
                auctionReservePrice,
                tokenId,
                false,
                false,
                gatedERC20.address,
                eth(1),
              );
              partyBid = contracts.partyBid;
              nftContract = contracts.nftContract;
              market = contracts.market;

              auctionId = await partyBid.auctionId();
            });

            // submit each contribution & check test conditions
            for (let contribution of contributions) {
              const { signerIndex, amount } = contribution;
              const signer = signers[signerIndex];

              it('Starts with the correct contribution amount', async () => {
                const totalContributed = await partyBid.totalContributed(
                  signer.address,
                );
                expect(totalContributed).to.equal(
                  eth(expectedTotalContributed[signer.address]),
                );
              });

              it('Starts with correct *total* contribution amount', async () => {
                const totalContributed =
                  await partyBid.totalContributedToParty();
                expect(totalContributed).to.equal(
                  eth(expectedTotalContributedToParty),
                );
              });

              it('Does not accept contribution from non-token holder', async () => {
                // expect balance is zero to begin with
                const tokenBalance = await gatedERC20.balanceOf(signer.address);
                await expect(weiToEth(tokenBalance)).to.equal(0);
                // expect contribute to fail
                await expect(
                  contribute(partyBid, signer, eth(amount)),
                ).to.be.revertedWith(
                  'Party::contribute: must hold tokens to contribute',
                );
              });

              it('Does not accept contribution from not-enough-token holder', async () => {
                // deposit to get SOME gated ERC20 tokens
                await signer.sendTransaction({
                  to: gatedERC20.address,
                  value: eth(0.5),
                });
                // attempt to contribute
                await expect(
                  contribute(partyBid, signer, eth(amount)),
                ).to.be.revertedWith(
                  'Party::contribute: must hold tokens to contribute',
                );
              });

              it('Accepts the contribution from sufficient token holders', async () => {
                // deposit to get ENOUGH gated ERC20 tokens
                await signer.sendTransaction({
                  to: gatedERC20.address,
                  value: eth(0.5),
                });

                await expect(contribute(partyBid, signer, eth(amount))).to.emit(
                  partyBid,
                  'Contributed',
                );
                // add to local expected variables
                expectedTotalContributed[signer.address] += amount;
                expectedTotalContributedToParty += amount;
              });

              it('Records the contribution amount', async () => {
                const totalContributed = await partyBid.totalContributed(
                  signer.address,
                );
                expect(totalContributed).to.equal(
                  eth(expectedTotalContributed[signer.address]),
                );
              });

              it('Records the *total* contribution amount', async () => {
                const totalContributed =
                  await partyBid.totalContributedToParty();
                expect(totalContributed).to.equal(
                  eth(expectedTotalContributedToParty),
                );
              });

              it('PartyBid ETH balance is total contributed to party', async () => {
                const balance = await provider.getBalance(partyBid.address);
                expect(balance).to.equal(eth(expectedTotalContributedToParty));
              });
            }

            // AFTER all contributions,
            // ends the party
            it('Does allow Finalize after the auction is over', async () => {
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
              // increase time on-chain so that auction can be finalized
              await provider.send('evm_increaseTime', [
                FOURTY_EIGHT_HOURS_IN_SECONDS,
              ]);
              await provider.send('evm_mine');

              // finalize auction
              await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');

              tokenVault = await getTokenVault(partyBid, signers[0]);
            });

            // has proper claim amounts
            for (let claim of claims[marketName]) {
              const { signerIndex, tokens, excessEth, totalContributed } =
                claim;
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

                const before = await getBalances(
                  provider,
                  tokenVault,
                  accounts,
                );

                // signer has no Party tokens before claim
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

                const after = await getBalances(provider, tokenVault, accounts);

                // ETH was transferred from PartyBid to contributor
                await expect(after.partyBid.eth.toNumber()).to.equal(
                  before.partyBid.eth.minus(excessEth).toNumber(),
                );

                // Tokens were transferred from Party to contributor
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
                await expect(partyBid.claim(contributor.address)).to.be
                  .reverted;
              });
            }
          });
        });
    });
  });
});
