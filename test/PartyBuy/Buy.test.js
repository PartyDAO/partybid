// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
const BigNumber = require('bignumber.js');
// ============ Internal Imports ============
const {
  encodeData,
  eth,
  weiToEth,
  getTotalContributed,
  contribute,
} = require('../helpers/utils');
const {
  getTokenVault,
  deploy,
  deployTestContractSetup,
} = require('./helpers/deploy');

const {
  PARTY_STATUS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
  ETH_FEE_BASIS_POINTS,
  TOKEN_FEE_BASIS_POINTS,
  TOKEN_SCALE,
  RESALE_MULTIPLIER,
} = require('./helpers/constants');
const { testCases } = require('./partyBuyTestCases.json');

describe('Buy', async () => {
  testCases
    .filter((testCase) => testCase['amountSpent'] > 0)
    .map((testCase, i) => {
      describe(`Case ${i}`, async () => {
        // get test case information
        const {
          maxPrice,
          splitRecipient,
          splitBasisPoints,
          contributions,
          amountSpent,
        } = testCase;
        // instantiate test vars
        let partyBuy,
          nftContract,
          allowList,
          partyDAOMultisig,
          multisigBalanceBefore,
          tokenVault,
          sellerContract,
          signer;
        const signers = provider.getWallets();
        const tokenId = 95;
        const totalContributed = new BigNumber(
          getTotalContributed(contributions),
        );
        const amtSpent = new BigNumber(amountSpent);
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
        const ethFee = amtSpent.times(ethFeeFactor);
        const expectedTotalSpent = amtSpent.plus(ethFee);

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
          multisigBalanceBefore = await provider.getBalance(
            partyDAOMultisig.address,
          );

          // submit contributions
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

        it('Is ACTIVE before Buy', async () => {
          const partyStatus = await partyBuy.partyStatus();
          expect(partyStatus).to.equal(PARTY_STATUS.ACTIVE);
        });

        it('Does not allow getClaimAmounts before Buy', async () => {
          await expect(
            partyBuy.getClaimAmounts(signers[0].address),
          ).to.be.revertedWith(
            'Party::getClaimAmounts: party still active; amounts undetermined',
          );
        });

        it('Does not allow totalEthUsed before Buy', async () => {
          await expect(
            partyBuy.totalEthUsed(signers[0].address),
          ).to.be.revertedWith(
            'Party::totalEthUsed: party still active; amounts undetermined',
          );
        });

        it('Fails if value is zero', async () => {
          // encode data to buy NFT
          const data = encodeData(sellerContract, 'sell', [
            eth(0),
            tokenId,
            nftContract.address,
          ]);
          // buy NFT
          await expect(partyBuy.buy(eth(0), sellerContract.address, data)).to.be
            .reverted;
        });

        it('Fails if AllowList is not set', async () => {
          // encode data to buy NFT
          const data = encodeData(sellerContract, 'sell', [
            eth(amountSpent),
            tokenId,
            nftContract.address,
          ]);
          // buy NFT
          await expect(
            partyBuy.buy(eth(amountSpent), sellerContract.address, data),
          ).to.be.revertedWith(
            'PartyBuy::buy: targetContract not on AllowList',
          );
          // set allow list to true
          await allowList.setAllowed(sellerContract.address, true);
        });

        it('Fails if external call reverts', async () => {
          // encode data to buy NFT
          const data = encodeData(sellerContract, 'revertSell', [
            eth(amountSpent),
            tokenId,
            nftContract.address,
          ]);
          // buy NFT
          await expect(
            partyBuy.buy(eth(amountSpent), sellerContract.address, data),
          ).to.be.reverted;
        });

        it('Fails if token is not in contract', async () => {
          // encode data to buy NFT
          const data = encodeData(sellerContract, 'fakeSell', [
            eth(amountSpent),
            tokenId,
            nftContract.address,
          ]);
          // buy NFT
          await expect(
            partyBuy.buy(eth(amountSpent), sellerContract.address, data),
          ).to.be.revertedWith('PartyBuy::buy: failed to buy token');
        });

        it('Buys the NFT successfully', async () => {
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

        it(`Doesn't accept contributions after Buy`, async () => {
          await expect(contribute(partyBuy, signers[0], eth(0.00001))).to.be
            .reverted;
        });

        it(`Doesn't allow Buy after initial Buy`, async () => {
          // encode data to buy NFT
          const data = encodeData(sellerContract, 'sell', [
            eth(amountSpent),
            tokenId,
            nftContract.address,
          ]);
          // buy NFT
          await expect(
            partyBuy.buy(eth(amountSpent), sellerContract.address, data),
          ).to.be.revertedWith('PartyBuy::buy: party not active');
        });

        it(`Doesn't allow Expire after Buy`, async () => {
          await expect(partyBuy.expire()).to.be.revertedWith(
            'PartyBuy::expire: party not active',
          );
        });

        it('Does allow getClaimAmounts before Expire', async () => {
          await expect(partyBuy.getClaimAmounts(signers[0].address)).to.not.be
            .reverted;
        });

        it('Does allow totalEthUsed before Expire', async () => {
          await expect(partyBuy.totalEthUsed(signers[0].address)).to.not.be
            .reverted;
        });

        it(`Is WON after Buy`, async () => {
          const partyStatus = await partyBuy.partyStatus();
          expect(partyStatus).to.equal(PARTY_STATUS.WON);
        });

        it(`Fractional Token Vault Owns the NFT`, async () => {
          const owner = await nftContract.ownerOf(tokenId);
          expect(owner).to.equal(tokenVault.address);
        });

        it(`Fractional Token Vault has correct reserve price`, async () => {
          const reservePrice = await tokenVault.reservePrice();
          expect(weiToEth(reservePrice)).to.equal(
            amtSpent.times(RESALE_MULTIPLIER).toNumber(),
          );
        });

        it('Has correct totalSpent', async () => {
          const totalSpent = await partyBuy.totalSpent();
          expect(weiToEth(totalSpent)).to.equal(expectedTotalSpent.toNumber());
        });

        it('Has correct balance of tokens in Party', async () => {
          const expectedPartyBidBalance = expectedTotalSpent.times(TOKEN_SCALE);
          const partyTokenBalance = await tokenVault.balanceOf(
            partyBuy.address,
          );
          expect(weiToEth(partyTokenBalance)).to.equal(
            expectedPartyBidBalance.toNumber(),
          );
        });

        it('Transferred token fee to PartyDAO multisig', async () => {
          const totalSupply = await tokenVault.totalSupply();
          const expectedMultisigBalance = tokenFeeFactor.times(
            weiToEth(totalSupply),
          );
          const multisigBalance = await tokenVault.balanceOf(
            partyDAOMultisig.address,
          );
          expect(weiToEth(multisigBalance)).to.equal(
            expectedMultisigBalance.toNumber(),
          );
        });

        it('Transferred tokens to splitRecipient', async () => {
          const totalSupply = await tokenVault.totalSupply();
          const expectedsplitRecipientBalance = splitRecipientFactor.times(
            weiToEth(totalSupply),
          );
          const splitRecipientBalance = await tokenVault.balanceOf(
            splitRecipient,
          );
          expect(weiToEth(splitRecipientBalance)).to.equal(
            expectedsplitRecipientBalance.toNumber(),
          );
        });

        it(`Transferred ETH fee to multisig`, async () => {
          const balanceBefore = new BigNumber(weiToEth(multisigBalanceBefore));
          const expectedBalanceAfter = balanceBefore.plus(ethFee);
          const multisigBalanceAfter = await provider.getBalance(
            partyDAOMultisig.address,
          );
          expect(weiToEth(multisigBalanceAfter)).to.equal(
            expectedBalanceAfter.toNumber(),
          );
        });

        it('Has correct balance of ETH in Party', async () => {
          const expectedEthBalance = totalContributed.minus(expectedTotalSpent);
          const ethBalance = await provider.getBalance(partyBuy.address);
          expect(weiToEth(ethBalance)).to.equal(expectedEthBalance.toNumber());
        });
      });
    });
});
