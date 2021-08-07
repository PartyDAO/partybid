// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
    eth,
    contribute,
    bidThroughParty,
} = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKETS } = require('../helpers/constants');

const testCases = [
    {
        reserve: 500,
        balance: 525
    },
    {
        reserve: 1,
        balance: 1.05
    }
];

describe('Maximum First Bid', async () => {
    MARKETS.map((marketName) => {
        describe(marketName, async () => {
            testCases.map((testCase, i) => {
                // get test case information
                const {reserve, balance} = testCase;
                describe(`Case ${i}`, async () => {
                    // instantiate test vars
                    let partyBid;
                    const signers = provider.getWallets();
                    const tokenId = 100;
                    const reservePrice = reserve;

                    before(async () => {
                        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
                        const contracts = await deployTestContractSetup(
                            marketName,
                            provider,
                            signers[0],
                            tokenId,
                            reservePrice,
                        );
                        partyBid = contracts.partyBid;

                        // contribute balance to PartyBid
                        await contribute(partyBid, signers[0], eth(balance));
                    });

                    it(`Allows a ${reservePrice} ETH first bid`, async () => {
                        await expect(bidThroughParty(partyBid, signers[0])).to.emit(partyBid, 'Bid');
                    });
                });
            });
        });
    });
});

describe('Failed Maximum First Bid', async () => {
    MARKETS.map((marketName) => {
        describe(marketName, async () => {
            testCases.map((testCase, i) => {
                // get test case information
                const {reserve, balance} = testCase;
                describe(`Case ${i}`, async () => {
                    // instantiate test vars
                    let partyBid;
                    const signers = provider.getWallets();
                    const tokenId = 100;
                    const reservePrice = reserve + 0.000000000001;

                    before(async () => {
                        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
                        const contracts = await deployTestContractSetup(
                            marketName,
                            provider,
                            signers[0],
                            tokenId,
                            reservePrice,
                        );
                        partyBid = contracts.partyBid;

                        // contribute balance to PartyBid
                        await contribute(partyBid, signers[0], eth(balance));});

                    it(`Does not allow a ${reservePrice} ETH bid`, async () => {
                        await expect(bidThroughParty(partyBid, signers[0])).to.be.reverted;
                    });
                });
            });
        });
    });
});

