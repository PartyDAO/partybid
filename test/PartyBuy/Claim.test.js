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
  encodeData,
} = require('../helpers/utils');
const {
  deploy,
  deployTestContractSetup,
  getTokenVault,
} = require('./helpers/deploy');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./helpers/constants');
const { testCases } = require('./partyBuyTestCases.json');

describe('Claim', async () => {
  testCases.map((testCase, i) => {
    describe(`Case ${i}`, async () => {
      // get test case information
      const {
        maxPrice,
        splitRecipient,
        splitBasisPoints,
        contributions,
        amountSpent,
        claims,
      } = testCase;
      // instantiate test vars
      let partyBuy,
        nftContract,
        allowList,
        partyDAOMultisig,
        tokenVault,
        sellerContract,
        signer;
      const signers = provider.getWallets();
      const firstSigner = signers[0];
      const tokenId = 95;

      before(async () => {
        [signer] = provider.getWallets();

        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
        const contracts = await deployTestContractSetup(
          provider,
          signer,
          eth(maxPrice),
          FOURTY_EIGHT_HOURS_IN_SECONDS,
          splitRecipient,
          splitBasisPoints,
          tokenId,
        );

        partyBuy = contracts.partyBuy;
        partyDAOMultisig = contracts.partyDAOMultisig;
        nftContract = contracts.nftContract;
        allowList = contracts.allowList;

        // submit contributions before bidding begins
        for (let contribution of contributions) {
          const { signerIndex, amount } = contribution;
          const signer = signers[signerIndex];
          await contribute(partyBuy, signer, eth(amount));
        }

        // deploy Seller contract & transfer NFT to Seller
        sellerContract = await deploy('Seller');
        await nftContract.transferFrom(
          signer.address,
          sellerContract.address,
          tokenId,
        );
      });

      it(`Reverts before Buy or Expire`, async () => {
        await expect(partyBuy.claim(firstSigner.address)).to.be.revertedWith(
          'Party::claim: party not finalized',
        );
      });

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
          const totalEthUsed = await partyBuy.totalEthUsed(contributor.address);
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
          const totalEthUsed = await partyBuy.totalEthUsed(contributor.address);
          const expectedEthUsed = new BigNumber(totalContributed).minus(
            excessEth,
          );
          expect(weiToEth(totalEthUsed)).to.equal(expectedEthUsed.toNumber());
        });

        it(`Does not allow a contributor to double-claim`, async () => {
          await expect(partyBuy.claim(contributor.address)).to.be.reverted;
        });
      }

      it('Gives zero for getClaimAmounts for non-contributor', async () => {
        const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
        const [tokenClaimAmount, ethClaimAmount] =
          await partyBuy.getClaimAmounts(randomAddress);
        expect(tokenClaimAmount).to.equal(0);
        expect(ethClaimAmount).to.equal(0);
      });

      it('Gives the zero for totalEthUsed for non-contributor', async () => {
        const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
        const totalEthUsed = await partyBuy.totalEthUsed(randomAddress);
        expect(totalEthUsed).to.equal(0);
      });

      it(`Reverts on Claim for non-contributor`, async () => {
        const randomAddress = '0xD115BFFAbbdd893A6f7ceA402e7338643Ced44a6';
        await expect(partyBuy.claim(randomAddress)).to.be.revertedWith(
          'Party::claim: not a contributor',
        );
      });
    });
  });
});
