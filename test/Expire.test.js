// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, contribute, bidThroughParty, expire } = require('./helpers/utils');
const { placeBid } = require('./helpers/externalTransactions');
const { deployTestContractSetup } = require('./helpers/deploy');
const { MARKETS, MARKET_NAMES, FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./helpers/constants');

describe.only('Expire', async () => {
  MARKETS.map((marketName) => {
    describe(marketName, async () => {
      describe(`Expiration`, async () => {
        // get test case information
        const auctionReservePrice = 1;
        const splitRecipient = '0x0000000000000000000000000000000000000000';
        const splitBasisPoints = 0;
        // instantiate test vars
        let partyBid, market, auctionId;
        const signers = provider.getWallets();
        const tokenId = 95;

        before(async () => {
          // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
          const contracts = await deployTestContractSetup(
            marketName,
            provider,
            signers[0],
            splitRecipient,
            splitBasisPoints,
            auctionReservePrice,
            tokenId,
          );
          partyBid = contracts.partyBid;
          market = contracts.market;

          auctionId = await partyBid.auctionId();
        });

        it('Accepts contributions before expiration', async () => {
          await contribute(partyBid, signers[1], eth(0.5))
        });

        it("Can't be expired before the time specified", async () => {
          await expect(expire(partyBid, signers[1])).to.be.revertedWith("PartyBid::expire: expiration time in future")
        });

        it("Can still accept contributions after the expiration time", async() => {
          // increase time on-chain so that auction can be expired
          await provider.send('evm_increaseTime', [
            FOURTY_EIGHT_HOURS_IN_SECONDS,
          ]);
          await provider.send('evm_mine');
          await contribute(partyBid, signers[1], eth(0.6))
        })

        it ("Can bid after the expiration time", async() => {
          await expect(
            bidThroughParty(partyBid, signers[1]),
          ).to.emit(partyBid, 'Bid');
        })


        it("Can't be expired if its winning the auction", async () => {
          await expect(expire (partyBid, signers[1])).to.be.revertedWith("PartyBid::expire: currently highest bidder")
        });

        it("Can't be expired by someone not in the party", async () => {
          // await expect(expire, partyBid, signers[2]).to.be.revertedWith("")
          // Do we care about this? It looks like we don't for 'bid' though this could be more damaging
        })

        it('Can be expired after the time specified', async () => {
          // Bid the auction up by someone else so we're no longer winning
          const eventName =
          marketName == MARKET_NAMES.FOUNDATION
            ? 'ReserveAuctionBidPlaced'
            : 'AuctionBid';
          await expect(
            placeBid(
              signers[0],
              market,
              auctionId,
              eth(2),
              marketName,
            ),
          ).to.emit(market, eventName);

          await expect(expire(partyBid, signers[1])).to.emit(partyBid, 'Finalized')
          //todo verify the args here that expired is true
        });

        it("Can't accept contributions after expiration", async () => {
          await expect(contribute(partyBid, signers[1], eth(0.5))).to.be.revertedWith("Party::contribute: party not active")
        });
      });
    });
  });
});
