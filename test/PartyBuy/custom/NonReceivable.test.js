// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { deploy, deployTestContractSetup } = require('../helpers/deploy');
const { eth, encodeData, contribute } = require('../../helpers/utils');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../helpers/constants');

describe('NonReceivable', async () => {
  const splitRecipient = '0x0000000000000000000000000000000000000000';
  const splitBasisPoints = 0;
  const maxPrice = 10;
  const tokenId = 95;
  let partyBuy, nftContract, allowList, sellerContract, signer;

  before(async () => {
    // GET RANDOM SIGNER & ARTIST
    [signer] = provider.getWallets();

    // DEPLOY PARTY BID CONTRACT
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
    nftContract = contracts.nftContract;
    allowList = contracts.allowList;

    // deploy Seller contract & transfer NFT to Seller
    sellerContract = await deploy('Seller');
    await nftContract.transferFrom(
      signer.address,
      sellerContract.address,
      tokenId,
    );

    // set allow list to true
    await allowList.setAllowed(sellerContract.address, true);

    await contribute(partyBuy, signer, eth(10));
  });

  it('Does not receive ETH', async () => {
    await expect(
      signer.sendTransaction({
        to: partyBuy.address,
        value: eth(1),
      }),
    ).to.be.reverted;
  });

  it('Does not receive ETH with Data', async () => {
    const data = encodeData(partyBuy, 'expire');
    await expect(
      signer.sendTransaction({
        to: partyBuy.address,
        value: eth(1),
        data,
      }),
    ).to.be.reverted;
  });

  it('Fails if external call re-enters', async () => {
    // encode data to buy NFT
    const data = encodeData(sellerContract, 'sellAndReenter', [
      eth(5),
      tokenId,
      nftContract.address,
    ]);
    // buy NFT
    await expect(
      partyBuy.buy(eth(5), sellerContract.address, data),
    ).to.be.revertedWith('re-enter failed');
  });
});
