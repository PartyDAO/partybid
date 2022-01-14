// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { deployTestContractSetup } = require('../helpers/deploy');
const { eth, weiToEth, contribute } = require('../../helpers/utils');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../helpers/constants');

describe('MaxContribute', async () => {
  const splitRecipient = '0x0000000000000000000000000000000000000000';
  const splitBasisPoints = 0;
  const maxPrice = 100;
  const tokenId = 95;
  let partyBuy, partyDAOMultisig, signer, artist;

  before(async () => {
    // GET RANDOM SIGNER & ARTIST
    [signer, artist] = provider.getWallets();

    // DEPLOY PARTY BID CONTRACT
    const contracts = await deployTestContractSetup(
      provider,
      artist,
      eth(maxPrice),
      FOURTY_EIGHT_HOURS_IN_SECONDS,
      splitRecipient,
      splitBasisPoints,
      tokenId,
    );

    partyBuy = contracts.partyBuy;
    partyDAOMultisig = contracts.partyDAOMultisig;
  });

  it('Returns the expected maximum', async () => {
    const max = await partyBuy.getMaximumContributions();
    await expect(weiToEth(max)).to.equal(102.5);
  });

  it('Accepts up to the max', async () => {
    await expect(contribute(partyBuy, signer, eth(102.5))).to.emit(
      partyBuy,
      'Contributed',
    );
  });

  it('Does not accept more than the max', async () => {
    await expect(contribute(partyBuy, signer, eth(0.1))).to.be.revertedWith(
      'PartyBuy::contribute: cannot contribute more than max',
    );
  });
});
