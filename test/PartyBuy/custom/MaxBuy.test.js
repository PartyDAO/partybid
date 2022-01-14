// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { deploy, deployTestContractSetup } = require('../helpers/deploy');
const { eth, contribute, encodeData } = require('../../helpers/utils');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../helpers/constants');

describe('MaxBuy', async () => {
  const splitRecipient = '0x0000000000000000000000000000000000000000';
  const splitBasisPoints = 0;
  const maxPrice = 100;
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
  });

  it('Doesnt allow Buy more than contributed', async () => {
    await contribute(partyBuy, signer, eth(50));
    // encode data to buy NFT
    const data = encodeData(sellerContract, 'sell', [
      eth(51),
      tokenId,
      nftContract.address,
    ]);
    // buy NFT
    await expect(
      partyBuy.buy(eth(51), sellerContract.address, data),
    ).to.be.revertedWith(
      'PartyBuy::buy: insuffucient funds to buy token plus fee',
    );
  });

  it('Doesnt allow Buy if cannot pay fee', async () => {
    // encode data to buy NFT
    const data = encodeData(sellerContract, 'sell', [
      eth(49.5),
      tokenId,
      nftContract.address,
    ]);
    // buy NFT
    await expect(
      partyBuy.buy(eth(49.5), sellerContract.address, data),
    ).to.be.revertedWith(
      'PartyBuy::buy: insuffucient funds to buy token plus fee',
    );
  });

  it('Doesnt allow Buy over maxPrice', async () => {
    await contribute(partyBuy, signer, eth(52.5));
    // encode data to buy NFT
    const data = encodeData(sellerContract, 'sell', [
      eth(101),
      tokenId,
      nftContract.address,
    ]);
    // buy NFT
    await expect(
      partyBuy.buy(eth(102.5), sellerContract.address, data),
    ).to.be.revertedWith("PartyBuy::buy: can't spend over max price");
  });

  it('Does allow Buy at exactly maxPrice', async () => {
    // encode data to buy NFT
    const data = encodeData(sellerContract, 'sell', [
      eth(100),
      tokenId,
      nftContract.address,
    ]);
    // buy NFT
    await expect(partyBuy.buy(eth(100), sellerContract.address, data)).to.emit(
      partyBuy,
      'Bought',
    );
  });
});
