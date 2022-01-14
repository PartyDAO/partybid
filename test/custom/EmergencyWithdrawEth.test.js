// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, weiToEth, emergencyWithdrawEth } = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKET_NAMES } = require('../helpers/constants');

describe('Emergency Withdraw ETH', async () => {
  // instantiate test vars
  let partyBid, nftContract, partyDAOMultisig, ethAmount;
  const signers = provider.getWallets();
  const tokenId = 100;
  const reservePrice = 500;
  const splitRecipient = '0x0000000000000000000000000000000000000000';
  const splitBasisPoints = 0;

  before(async () => {
    // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
    const contracts = await deployTestContractSetup(
      MARKET_NAMES.ZORA,
      provider,
      signers[0],
      splitRecipient,
      splitBasisPoints,
      reservePrice,
      tokenId,
      true,
    );
    partyBid = contracts.partyBid;
    partyDAOMultisig = contracts.partyDAOMultisig;
    nftContract = contracts.nftContract;

    ethAmount = 1;
    await signers[0].sendTransaction({
      to: partyBid.address,
      value: eth(ethAmount),
    });
  });

  it('ETH *cannot* be withdrawn by non-multisig', async () => {
    await expect(
      emergencyWithdrawEth(partyBid, signers[1], eth(ethAmount)),
    ).to.be.revertedWith('Party:: only PartyDAO multisig');
    await expect(
      emergencyWithdrawEth(partyBid, signers[2], eth(ethAmount)),
    ).to.be.revertedWith('Party:: only PartyDAO multisig');
  });

  it('ETH *can* be withdrawn by multisig', async () => {
    // get balance before
    const partyBidBalanceBefore = await provider.getBalance(partyBid.address);
    const multisigBalanceBefore = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // withdraw ETH
    await expect(emergencyWithdrawEth(partyBid, signers[0], eth(ethAmount))).to
      .not.be.reverted;

    // get balance before
    const partyBidBalanceAfter = await provider.getBalance(partyBid.address);
    const multisigBalanceAfter = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // expect eth amount transferred from PartyBid to multisig
    await expect(weiToEth(partyBidBalanceBefore)).to.not.equal(0);
    await expect(weiToEth(partyBidBalanceAfter)).to.equal(0);
    await expect(weiToEth(multisigBalanceAfter)).to.be.greaterThan(
      weiToEth(multisigBalanceBefore),
    );
  });

  it('ETH *can* withdraw less than full balanace', async () => {
    await signers[0].sendTransaction({
      to: partyBid.address,
      value: eth(ethAmount),
    });

    // get balance before
    const partyBidBalanceBefore = await provider.getBalance(partyBid.address);
    const multisigBalanceBefore = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // withdraw ETH
    await expect(emergencyWithdrawEth(partyBid, signers[0], eth(ethAmount / 2)))
      .to.not.be.reverted;

    // get balance before
    const partyBidBalanceAfter = await provider.getBalance(partyBid.address);
    const multisigBalanceAfter = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // expect eth amount transferred from PartyBid to multisig
    await expect(weiToEth(partyBidBalanceBefore)).to.not.equal(0);
    await expect(weiToEth(partyBidBalanceAfter)).to.not.equal(0);
    await expect(weiToEth(multisigBalanceAfter)).to.be.greaterThan(
      weiToEth(multisigBalanceBefore),
    );
  });

  it('ETH *can* sweep full ETH balance if value is greater than balance', async () => {
    await signers[0].sendTransaction({
      to: partyBid.address,
      value: eth(ethAmount),
    });

    // get balance before
    const partyBidBalanceBefore = await provider.getBalance(partyBid.address);
    const multisigBalanceBefore = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // withdraw ETH
    await expect(
      emergencyWithdrawEth(partyBid, signers[0], eth(ethAmount * 10)),
    ).to.not.be.reverted;

    // get balance before
    const partyBidBalanceAfter = await provider.getBalance(partyBid.address);
    const multisigBalanceAfter = await provider.getBalance(
      partyDAOMultisig.address,
    );

    // expect eth amount transferred from PartyBid to multisig
    await expect(weiToEth(partyBidBalanceBefore)).to.not.equal(0);
    await expect(weiToEth(partyBidBalanceAfter)).to.equal(0);
    await expect(weiToEth(multisigBalanceAfter)).to.be.greaterThan(
      weiToEth(multisigBalanceBefore),
    );
  });
});
