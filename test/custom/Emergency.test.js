// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
    eth,
    emergencyWithdrawEth,
    emergencyCall,
    emergencyForceLost
} = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const { PARTY_STATUS } = require('../helpers/constants');
const { MARKET_NAMES } = require('../helpers/constants');

describe('Emergency Withdraw ETH', async () => {
    // instantiate test vars
    let partyBid,
        market,
        nftContract,
        partyDAOMultisig,
        auctionId;
    const signers = provider.getWallets();
    const tokenId = 100;
    const reservePrice = 500;

    before(async () => {
        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
        const contracts = await deployTestContractSetup(
            MARKET_NAMES.ZORA,
            provider,
            signers[0],
            tokenId,
            reservePrice,
            true,
        );
        partyBid = contracts.partyBid;
        market = contracts.market;
        partyDAOMultisig = contracts.partyDAOMultisig;
        nftContract = contracts.nftContract;
        auctionId = await partyBid.auctionId();
    });

    it('Can withdraw ETH', async () => {
        await signers[0].sendTransaction({
            to: partyBid.address,
            value: eth(1)
        });

        await expect(emergencyWithdrawEth(partyBid, signers[0], eth(1))).to.not.be.reverted;
    });

    it('Can force lost', async () => {
        // check that party status is NOT lost
        let partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.not.equal(PARTY_STATUS.AUCTION_LOST);

        // call force lost
        await expect(emergencyForceLost(partyBid, signers[0])).to.not.be.reverted;

        // check that party status is lost
        partyStatus = await partyBid.partyStatus();
        expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_LOST);
    });
});

