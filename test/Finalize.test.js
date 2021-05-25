// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
  eth,
  weiToEth,
  getTotalContributed,
  contribute,
  placeBid,
} = require('./helpers/utils');
const { deployTestContractSetup } = require('./helpers/deploy');
const {
  AUCTION_STATUS,
  FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('./helpers/constants');
const { testCases } = require('./testCases.json');

testCases.map((testCase) => {
  describe('Finalize', async () => {
    // get test case information
    const { auctionReservePrice, contributions, bids, finalBid } = testCase;
    // instantiate test vars
    let partyBid,
      market,
      nftContract,
      partyDAOMultisig,
      auctionId,
      multisigBalanceBefore;
    const totalContributed = getTotalContributed(contributions);
    const lastBid = bids[bids.length - 1];
    const partyBidWins = lastBid.placedByPartyBid && lastBid.success;
    const signers = provider.getWallets();
    const tokenId = 100;

    before(async () => {
      // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
      const contracts = await deployTestContractSetup(
        signers[0],
        tokenId,
        auctionReservePrice,
      );
      partyBid = contracts.partyBid;
      market = contracts.market;
      partyDAOMultisig = contracts.partyDAOMultisig;
      nftContract = contracts.nftContract;

      auctionId = await partyBid.auctionId();

      multisigBalanceBefore = await provider.getBalance(
        partyDAOMultisig.address,
      );

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
          await placeBid(signers[0], market, auctionId, eth(amount));
        }
      }
    });

    it('Does not allow Finalize before the auction is over', async () => {
      await expect(partyBid.finalize()).to.be.reverted;
    });

    it('Is ACTIVE before Finalize', async () => {
      const auctionStatus = await partyBid.auctionStatus();
      expect(auctionStatus).to.equal(AUCTION_STATUS.ACTIVE);
    });

    it('Has zero tokenSupply', async () => {
      const totalSupply = await partyBid.totalSupply();
      expect(totalSupply).to.equal(0);
    });

    it('Does allow Finalize after the auction is over', async () => {
      // increase time on-chain so that auction can be finalized
      await provider.send('evm_increaseTime', [FOURTY_EIGHT_HOURS_IN_SECONDS]);
      await provider.send('evm_mine');

      // finalize auction
      await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');
    });

    if (partyBidWins) {
      it(`Is WON after Finalize`, async () => {
        const auctionStatus = await partyBid.auctionStatus();
        expect(auctionStatus).to.equal(AUCTION_STATUS.WON);
      });

      it(`Owns the NFT`, async () => {
        const owner = await nftContract.ownerOf(tokenId);
        expect(owner).to.equal(partyBid.address);
      });

      it('Has correct totalSpent, totalSupply of tokens, and balanceOf PartyBid tokens', async () => {
        const expectedTotalSpent = eth(finalBid * 1.05);
        const expectedTotalSupply = eth(finalBid * 1.05 * 1000);

        const totalSpent = await partyBid.totalSpent();
        expect(totalSpent).to.equal(expectedTotalSpent);

        const totalSupply = await partyBid.totalSupply();
        expect(totalSupply).to.equal(expectedTotalSupply);

        const partyBidTokenBalance = await partyBid.balanceOf(partyBid.address);
        expect(partyBidTokenBalance).to.equal(expectedTotalSupply);
      });

      // TODO: check PartyBid ETH balance -- total contributed minus final bid minus fee

      it(`Transferred fee to multisig`, async () => {
        const balanceBeforeAsFloat = parseFloat(
          weiToEth(multisigBalanceBefore),
        );

        const multisigBalanceWithFee = eth(
          balanceBeforeAsFloat + finalBid * 0.05,
        );
        const multisigBalanceAfter = await provider.getBalance(
          partyDAOMultisig.address,
        );
        expect(weiToEth(multisigBalanceAfter)).to.equal(
          weiToEth(multisigBalanceWithFee),
        );
      });
    } else {
      it(`Is LOST after Finalize`, async () => {
        const auctionStatus = await partyBid.auctionStatus();
        expect(auctionStatus).to.equal(AUCTION_STATUS.LOST);
      });

      it(`Does not own the NFT`, async () => {
        const owner = await nftContract.ownerOf(tokenId);
        expect(owner).to.not.equal(partyBid.address);
      });

      it('Has zero totalSpent, totalSupply of tokens, and balanceOf PartyBid', async () => {
        const totalSupply = await partyBid.totalSupply();
        expect(totalSupply).to.equal(0);

        const totalSpent = await partyBid.totalSpent();
        expect(totalSpent).to.equal(0);

        const partyBidTokenBalance = await partyBid.balanceOf(partyBid.address);
        expect(partyBidTokenBalance).to.equal(0);
      });

      it(`Did not transfer fee to multisig`, async () => {
        const multisigBalanceAfter = await provider.getBalance(
          partyDAOMultisig.address,
        );
        expect(multisigBalanceAfter).to.equal(multisigBalanceBefore);
      });
    }
  });
});
