// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth } = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const { PARTY_STATUS } = require('./helpers/constants');

describe('Deploy', async () => {
  let partyBid, signer, artist;

  before(async () => {
    // GET RANDOM SIGNER & ARTIST
    [signer, artist] = provider.getWallets();

    // DEPLOY PARTY BID CONTRACT
    const contracts = await deployTestContractSetup(provider, artist);
    partyBid = contracts.partyBid;
  });

  it('Party Status is Active', async () => {
    const partyStatus = await partyBid.partyStatus();
    expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_ACTIVE);
  });

  it('Total contributed to party is zero', async () => {
    const totalContributedToParty = await partyBid.totalContributedToParty();
    expect(totalContributedToParty).to.equal(eth(0));
  });

  it('Highest bid is zero', async () => {
    const highestBid = await partyBid.highestBid();
    expect(highestBid).to.equal(eth(0));
  });

  it('Total spent is zero', async () => {
    const totalSpent = await partyBid.totalSpent();
    expect(totalSpent).to.equal(eth(0));
  });

  it('Total Contributed is zero for random account', async () => {
    const totalContributed = await partyBid.totalContributed(signer.address);
    expect(totalContributed).to.equal(eth(0));
  });
});
