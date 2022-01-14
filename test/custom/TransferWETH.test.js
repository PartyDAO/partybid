// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, getBalances } = require('../helpers/utils');
const { placeBid } = require('../helpers/externalTransactions');
const { deployTestContractSetup, deploy } = require('../helpers/deploy');
const {
  MARKETS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('../helpers/constants');

describe('Transfer WETH', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      // instantiate test vars
      let partyBid, token, nonPayable, accounts;
      const contributionAmount = 1;
      const reservePrice = 1;
      const tokenId = 95;
      const splitRecipient = '0x0000000000000000000000000000000000000000';
      const splitBasisPoints = 0;

      before(async () => {
        const signers = provider.getWallets();

        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
        const contracts = await deployTestContractSetup(
          marketName,
          provider,
          signers[0],
          splitRecipient,
          splitBasisPoints,
          reservePrice,
          tokenId,
        );
        partyBid = contracts.partyBid;
        token = contracts.weth;

        const auctionId = await partyBid.auctionId();

        // place bid from signer to kick off auction
        await placeBid(
          signers[0],
          contracts.market,
          auctionId,
          eth(1),
          marketName,
        );

        // deploy payable contract and send ETH to it
        const payable = await deploy('PayableContract');
        await signers[0].sendTransaction({
          value: eth(contributionAmount),
          to: payable.address,
        });

        // deploy non-payable contract
        nonPayable = await deploy('NonPayableContract');

        // destruct payable contract, sending ETH to non-payable
        await payable.destruct(nonPayable.address);

        // instantiate balances of addresses before
        accounts = [
          {
            name: 'partyBid',
            address: partyBid.address,
          },
          {
            name: 'nonPayable',
            address: nonPayable.address,
          },
        ];
      });

      it('Has correct balances before contribute', async () => {
        const balances = await getBalances(provider, token, accounts);
        // partyBid has ETH before contribute
        expect(balances.partyBid.eth.toNumber()).to.equal(0);
        // partyBid has no WETH before contribute
        expect(balances.partyBid.tokens.toNumber()).to.equal(0);

        // contributor has ETH before contribute
        expect(balances.nonPayable.eth.toNumber()).to.equal(contributionAmount);
        // contributor has no WETH before contribute
        expect(balances.nonPayable.tokens.toNumber()).to.equal(0);
      });

      it('Accepts contribution from contract', async () => {
        // submit contribution from non-payable contract
        await expect(
          nonPayable.contribute(partyBid.address, eth(contributionAmount)),
        ).to.emit(partyBid, 'Contributed');
      });

      it('Has correct balances after contribute, before claim', async () => {
        const balances = await getBalances(provider, token, accounts);
        // partyBid has ETH after contribute, before claim
        expect(balances.partyBid.eth.toNumber()).to.equal(contributionAmount);
        // partyBid has no WETH after contribute, before claim
        expect(balances.partyBid.tokens.toNumber()).to.equal(0);

        // contributor has ETH after contribute, before claim
        expect(balances.nonPayable.eth.toNumber()).to.equal(0);
        // contributor has no WETH after contribute, before claim
        expect(balances.nonPayable.tokens.toNumber()).to.equal(0);
      });

      it('Allows Finalize', async () => {
        // increase time on-chain so that auction can be finalized
        await provider.send('evm_increaseTime', [
          FOURTY_EIGHT_HOURS_IN_SECONDS,
        ]);
        await provider.send('evm_mine');

        // finalize auction
        await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');
      });

      it('Allows Claim', async () => {
        // claim succeeds; event is emitted
        await expect(partyBid.claim(nonPayable.address))
          .to.emit(partyBid, 'Claimed')
          .withArgs(
            nonPayable.address,
            eth(contributionAmount),
            eth(contributionAmount),
            eth(0),
          );
      });

      it('Has correct balances after claim', async () => {
        const balances = await getBalances(provider, token, accounts);
        // partyBid has ETH after contribute, before claim
        expect(balances.partyBid.eth.toNumber()).to.equal(0);
        // partyBid has no WETH after contribute, before claim
        expect(balances.partyBid.tokens.toNumber()).to.equal(0);

        // contributor has ETH after contribute, before claim
        expect(balances.nonPayable.eth.toNumber()).to.equal(0);
        // contributor has no WETH after contribute, before claim
        expect(balances.nonPayable.tokens.toNumber()).to.equal(
          contributionAmount,
        );
      });
    });
  });
});
