// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth } = require('./utils');
const { deployTestSetupFoundation } = require('./deploy');
const { AUCTION_STATUS } = require('./constants');

describe('Deploy', async () => {
  let partyBid, signer, artist;

  before(async () => {
    // GET RANDOM SIGNER & ARTIST
    [signer, artist] = provider.getWallets();

    // DEPLOY PARTY BID CONTRACT
    const contracts = await deployTestSetupFoundation(artist);
    partyBid = contracts.partyBid;
  });

  it('Auction Status is Active', async () => {
    const auctionStatus = await partyBid.auctionStatus();
    expect(auctionStatus).to.equal(AUCTION_STATUS.ACTIVE);
  });

  it('Contributions claimed is zero', async () => {
    const totalClaimed = await partyBid.totalContributionsClaimed();
    expect(totalClaimed).to.equal(eth(0));
  });

  it('Highest bid is zero', async () => {
    const highestBid = await partyBid.highestBid();
    expect(highestBid).to.equal(eth(0));
  });

  it('Highest bid plus fee is zero', async () => {
    const highestBidPlusFee = await partyBid.highestBidPlusFee();
    expect(highestBidPlusFee).to.equal(eth(0));
  });

  it('ERC-20 name is right', async () => {
    const name = await partyBid.name();
    expect(name).to.equal('Party');
  });

  it('ERC-20 symbol is right', async () => {
    const symbol = await partyBid.symbol();
    expect(symbol).to.equal('PARTY');
  });

  it('ERC-20 decimals are right', async () => {
    const decimals = await partyBid.decimals();
    expect(decimals).to.equal(18);
  });

  it('ERC-20 total supply is zero', async () => {
    const totalSupply = await partyBid.totalSupply();
    expect(totalSupply).to.equal(eth(0));
  });

  it('ERC-20 balance is zero for random account', async () => {
    const balance = await partyBid.balanceOf(signer.address);
    expect(balance).to.equal(eth(0));
  });
});
