// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  initExpectedTotalContributed,
  contribute,
} = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('Contribute', async () => {
    // get test case information
    let partyBid;
    const { contributions } = testCase;
    const signers = provider.getWallets();

    let expectedTotalContributedToParty = 0;
    const expectedTotalContributed = initExpectedTotalContributed(signers);

    before(async () => {
      // DEPLOY PARTY BID CONTRACT
      const contracts = await deployTestContractSetup(signers[0]);
      partyBid = contracts.partyBid;
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

      it('PartyBid ETH balance is total contributed to party', async () => {
        const balance = await provider.getBalance(partyBid.address);
        expect(balance).to.equal(eth(expectedTotalContributedToParty));
      });

      it('ERC-20 balance is zero for the contributor', async () => {
        const balance = await partyBid.balanceOf(signer.address);
        expect(balance).to.equal(eth(0));
      });
    }
  });
});
