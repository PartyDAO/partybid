// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  weiToEth,
  contribute,
  placeBid,
  redeem,
  transfer,
  expectRedeemable,
} = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./helpers/constants');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('Redeem', async () => {
    // get test case information
    const { auctionReservePrice, contributions, bids, claims } = testCase;
    // instantiate test vars
    let partyBid, market, auctionId;
    const signers = provider.getWallets();
    const firstSigner = signers[0];
    const tokenId = 100;
    let ethAmountAdded = 0;
    let ethAmountRedeemed = 0;

    before(async () => {
      // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
      const contracts = await deployTestContractSetup(
        firstSigner,
        tokenId,
        auctionReservePrice,
      );
      partyBid = contracts.partyBid;
      market = contracts.market;

      auctionId = await partyBid.auctionId();

      // submit contributions before bidding begins
      for (let contribution of contributions) {
        const { signerIndex, amount } = contribution;
        const signer = signers[signerIndex];
        await contribute(partyBid, signer, eth(amount));
      }

      // submit the valid bids in order
      for (let bid of bids) {
        const { placedByPartyBid, amount, success } = bid;
        if (success && placedByPartyBid) {
          await partyBid.bid();
        } else if (success && !placedByPartyBid) {
          await placeBid(firstSigner, market, auctionId, eth(amount));
        }
      }

      // finalize the auction
      await provider.send('evm_increaseTime', [FOURTY_EIGHT_HOURS_IN_SECONDS]);
      await provider.send('evm_mine');
      await partyBid.finalize();
    });

    it(`Reverts if token holder has no tokens`, async () => {
      await expect(partyBid.redeem(eth(10))).to.be.revertedWith(
        'redeem amount exceeds balance',
      );
    });

    it(`Has expected state variables before ETH has been transferred in, even during partially claimed state`, async () => {
      await expectRedeemable(
        provider,
        partyBid,
        ethAmountAdded,
        ethAmountRedeemed,
      );

      for (let claim of claims) {
        const { signerIndex } = claim;
        const contributor = signers[signerIndex];
        await partyBid.claim(contributor.address);

        await expectRedeemable(
          provider,
          partyBid,
          ethAmountAdded,
          ethAmountRedeemed,
        );
      }
    });

    it(`Has expected state variables after ETH is transferred in`, async () => {
      const amountToSend = 10;

      // transfer ETH into the contract
      const signer = signers[0];
      await signer.sendTransaction({
        to: partyBid.address,
        value: eth(amountToSend),
      });

      ethAmountAdded += amountToSend;

      await expectRedeemable(
        provider,
        partyBid,
        ethAmountAdded,
        ethAmountRedeemed,
      );
    });

    it(`Reverts with zero token amount`, async () => {
      await expect(partyBid.redeem(0)).to.be.revertedWith(
        "can't redeem zero tokens",
      );
    });

    it(`Reverts with greater token amount than balance`, async () => {
      const tokenBalance = await partyBid.balanceOf(signers[0].address);
      const tokenBalanceFloat = parseFloat(weiToEth(tokenBalance));

      await expect(tokenBalanceFloat).to.be.greaterThan(0);

      const doubleTokenBalance = eth(2 * tokenBalanceFloat);
      await expect(partyBid.redeem(doubleTokenBalance)).to.be.revertedWith(
        'redeem amount exceeds balance',
      );
    });

    if (claims.length >= 1) {
      const claim = claims[0];
      const { signerIndex, tokens } = claim;
      const contributor = signers[signerIndex];
      const redeemAmount = tokens;

      it(`Allows Redeem FULL token amount`, async () => {
        // TODO: check balance after
        // const balanceBefore = await partyBid.balanceOf(contributor.address);
        await expect(redeem(partyBid, contributor, eth(redeemAmount))).to.emit(
          partyBid,
          'Redeemed',
        );
      });

      it(`Doesn't allow double redeem`, async () => {
        await expect(
          redeem(partyBid, contributor, eth(tokens)),
        ).to.be.revertedWith('redeem amount exceeds balance');
      });
    }

    if (claims.length >= 2) {
      const claim = claims[1];
      const { signerIndex, tokens } = claim;
      const contributor = signers[signerIndex];
      const recipientSigner = provider.createEmptyWallet();

      it(`Allows Redeem PARTIAL token amount`, async () => {
        await expect(redeem(partyBid, contributor, eth(tokens / 2))).to.emit(
          partyBid,
          'Redeemed',
        );
      });

      it(`Allows Redeem transferred tokens`, async () => {
        // transfer tokens to recipient
        await transfer(
          partyBid,
          contributor,
          recipientSigner.address,
          eth(tokens / 2),
        );
        // fund recipient with gas money
        await signers[0].sendTransaction({
          to: recipientSigner.address,
          value: eth(1),
        });
        // redeem from recipient
        await expect(
          redeem(partyBid, recipientSigner, eth(tokens / 2)),
        ).to.emit(partyBid, 'Redeemed');
      });
    }

    // TODO: CHECK FOR EACH REDEEM
    // totalSupply is reduced by token amount
    // balanceOf claimer is reduced by token amount
    // eth is sent to recipient

    // TODO: add test for redeem before all is has claimed!
  });
});
