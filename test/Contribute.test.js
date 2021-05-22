// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, deployPartyBid, contribute } = require('./utils');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('Contribute', async () => {
    // get test case information
    const { contributions } = testCase;
    let partyBid;
    let expectedTotalContributedToParty = 0;
    const expectedTotalContributed = {};
    const signers = provider.getWallets();
    signers.map((signer) => {
      expectedTotalContributed[signer.address] = 0;
    });

    before(async () => {
      // DEPLOY PARTY BID CONTRACT
      partyBid = await deployPartyBid();
    });

    // submit each contribution & check test conditions
    for (let contribution of contributions) {
      const { signerIndex, amount } = contribution;
      const signer = signers[signerIndex];

      it('Starts with correct the contribution amount', async () => {
        const totalContributed = await partyBid.totalContributed(
          signer.address,
        );
        expect(totalContributed).to.equal(
          eth(expectedTotalContributed[signer.address]),
        );
      });

      it('Starts with correct *total* contribution amount', async () => {
        const totalContributed = await partyBid.totalContributedToParty();
        expect(totalContributed).to.equal(eth(expectedTotalContributedToParty));
      });

      it('Accepts the contribution', async () => {
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
        const totalContributed = await partyBid.totalContributedToParty();
        expect(totalContributed).to.equal(eth(expectedTotalContributedToParty));
      });

      it('ERC-20 balance is zero for the contributor', async () => {
        const balance = await partyBid.balanceOf(signer.address);
        expect(balance).to.equal(eth(0));
      });
    }
  });
});
