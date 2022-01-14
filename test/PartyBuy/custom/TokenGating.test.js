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
  encodeData,
  getBalances,
} = require('../../helpers/utils');
const {
  deployTestContractSetup,
  deploy,
  getTokenVault,
} = require('../helpers/deploy');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../helpers/constants');
const { testCases } = require('../partyBuyTestCases.json');

// indexes of test cases with one contribution per signer
const compatibleTestCases = [2, 3, 4, 7];

describe('TokenGating', async () => {
  testCases
    .filter((testCase, i) => compatibleTestCases.includes(i))
    .map((testCase, i) => {
      describe(`Case ${i}`, async () => {
        // get test case information
        let partyBuy,
          signer,
          nftContract,
          sellerContract,
          gatedERC20,
          allowList,
          tokenVault;
        const {
          splitRecipient,
          splitBasisPoints,
          contributions,
          maxPrice,
          amountSpent,
          claims,
        } = testCase;
        const tokenId = 95;
        const signers = provider.getWallets();
        let expectedTotalContributedToParty = 0;
        const expectedTotalContributed = initExpectedTotalContributed(signers);

        before(async () => {
          // GET RANDOM SIGNER & ARTIST
          [signer] = provider.getWallets();

          gatedERC20 = await deploy('EtherToken');

          // DEPLOY PARTY BID CONTRACT
          const contracts = await deployTestContractSetup(
            provider,
            signer,
            eth(maxPrice),
            FOURTY_EIGHT_HOURS_IN_SECONDS,
            splitRecipient,
            splitBasisPoints,
            tokenId,
            false,
            gatedERC20.address,
            eth(1),
          );

          partyBuy = contracts.partyBuy;
          nftContract = contracts.nftContract;
          allowList = contracts.allowList;

          // deploy Seller contract & transfer NFT to Seller
          sellerContract = await deploy('Seller');
          await nftContract.transferFrom(
            signer.address,
            sellerContract.address,
            tokenId,
          );
        });

        // submit each contribution & check test conditions
        for (let contribution of contributions) {
          const { signerIndex, amount } = contribution;
          const signer = signers[signerIndex];

          it('Starts with the correct contribution amount', async () => {
            const totalContributed = await partyBuy.totalContributed(
              signer.address,
            );
            expect(totalContributed).to.equal(
              eth(expectedTotalContributed[signer.address]),
            );
          });

          it('Starts with correct *total* contribution amount', async () => {
            const totalContributed = await partyBuy.totalContributedToParty();
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
              contribute(partyBuy, signer, eth(amount)),
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
              contribute(partyBuy, signer, eth(amount)),
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

            await expect(contribute(partyBuy, signer, eth(amount))).to.emit(
              partyBuy,
              'Contributed',
            );
            // add to local expected variables
            expectedTotalContributed[signer.address] += amount;
            expectedTotalContributedToParty += amount;
          });

          it('Records the contribution amount', async () => {
            const totalContributed = await partyBuy.totalContributed(
              signer.address,
            );
            expect(totalContributed).to.equal(
              eth(expectedTotalContributed[signer.address]),
            );
          });

          it('Records the *total* contribution amount', async () => {
            const totalContributed = await partyBuy.totalContributedToParty();
            expect(totalContributed).to.equal(
              eth(expectedTotalContributedToParty),
            );
          });

          it('PartyBid ETH balance is total contributed to party', async () => {
            const balance = await provider.getBalance(partyBuy.address);
            expect(balance).to.equal(eth(expectedTotalContributedToParty));
          });
        }

        // AFTER all contributions,
        // ends the party
        if (amountSpent > 0) {
          it('Buys the NFT', async () => {
            // set allow list to true
            await allowList.setAllowed(sellerContract.address, true);
            // encode data to buy NFT
            const data = encodeData(sellerContract, 'sell', [
              eth(amountSpent),
              tokenId,
              nftContract.address,
            ]);
            // buy NFT
            await expect(
              partyBuy.buy(eth(amountSpent), sellerContract.address, data),
            ).to.emit(partyBuy, 'Bought');
            // query token vault
            tokenVault = await getTokenVault(partyBuy, signers[0]);
          });
        } else {
          it('Expires after Party is timed out', async () => {
            // increase time on-chain so that party can be expired
            await provider.send('evm_increaseTime', [
              FOURTY_EIGHT_HOURS_IN_SECONDS,
            ]);
            await provider.send('evm_mine');
            // expire party
            await expect(partyBuy.expire()).to.emit(partyBuy, 'Expired');
          });
        }

        // has proper claim amounts
        for (let claim of claims) {
          const { signerIndex, tokens, excessEth, totalContributed } = claim;
          const contributor = signers[signerIndex];
          it('Gives the correct values for getClaimAmounts before claim is called', async () => {
            const [tokenClaimAmount, ethClaimAmount] =
              await partyBuy.getClaimAmounts(contributor.address);
            expect(weiToEth(tokenClaimAmount)).to.equal(tokens);
            expect(weiToEth(ethClaimAmount)).to.equal(excessEth);
          });

          it('Gives the correct value for totalEthUsed before claim is called', async () => {
            const totalEthUsed = await partyBuy.totalEthUsed(
              contributor.address,
            );
            const expectedEthUsed = new BigNumber(totalContributed).minus(
              excessEth,
            );
            expect(weiToEth(totalEthUsed)).to.equal(expectedEthUsed.toNumber());
          });

          it(`Allows Claim, transfers ETH and tokens to contributors after Finalize`, async () => {
            const accounts = [
              {
                name: 'partyBuy',
                address: partyBuy.address,
              },
              {
                name: 'contributor',
                address: contributor.address,
              },
            ];

            const before = await getBalances(provider, tokenVault, accounts);

            // signer has no Party tokens before claim
            expect(before.contributor.tokens.toNumber()).to.equal(0);

            // claim succeeds; event is emitted
            await expect(partyBuy.claim(contributor.address))
              .to.emit(partyBuy, 'Claimed')
              .withArgs(
                contributor.address,
                eth(totalContributed),
                eth(excessEth),
                eth(tokens),
              );

            const after = await getBalances(provider, tokenVault, accounts);

            // ETH was transferred from PartyBuy to contributor
            await expect(after.partyBuy.eth.toNumber()).to.equal(
              before.partyBuy.eth.minus(excessEth).toNumber(),
            );

            // Tokens were transferred from Party to contributor
            await expect(after.partyBuy.tokens.toNumber()).to.equal(
              before.partyBuy.tokens.minus(tokens).toNumber(),
            );
            await expect(after.contributor.tokens.toNumber()).to.equal(
              before.contributor.tokens.plus(tokens).toNumber(),
            );
          });

          it('Gives the same values for getClaimAmounts after claim is called', async () => {
            const [tokenClaimAmount, ethClaimAmount] =
              await partyBuy.getClaimAmounts(contributor.address);
            expect(weiToEth(tokenClaimAmount)).to.equal(tokens);
            expect(weiToEth(ethClaimAmount)).to.equal(excessEth);
          });

          it('Gives the same value for totalEthUsed after claim is called', async () => {
            const totalEthUsed = await partyBuy.totalEthUsed(
              contributor.address,
            );
            const expectedEthUsed = new BigNumber(totalContributed).minus(
              excessEth,
            );
            expect(weiToEth(totalEthUsed)).to.equal(expectedEthUsed.toNumber());
          });

          it(`Does not allow a contributor to double-claim`, async () => {
            await expect(partyBuy.claim(contributor.address)).to.be.reverted;
          });
        }
      });
    });
});
