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
    cancelAuction
} = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const {
    PARTY_STATUS,
} = require('../helpers/constants');
const { MARKETS } = require('../helpers/constants');
const { testCases } = require('../testCases.json');

describe('Auction Canceled', async () => {
    MARKETS.map((marketName) => {
        describe(marketName, async () => {
            testCases.map((testCase, i) => {
                describe(`Case ${i}`, async () => {
                    // get test case information
                    const {
                        auctionReservePrice,
                        contributions,
                        claims
                    } = testCase;
                    // instantiate test vars
                    let partyBid,
                        market,
                        nftContract,
                        partyDAOMultisig,
                        auctionId,
                        multisigBalanceBefore;
                    const signers = provider.getWallets();
                    const tokenId = 100;
                    const artistSigner = signers[0];

                    before(async () => {
                        // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
                        const contracts = await deployTestContractSetup(
                            marketName,
                            provider,
                            artistSigner,
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
                    });

                    it('Does not allow Finalize before the auction is over', async () => {
                        await expect(partyBid.finalize()).to.be.reverted;
                    });

                    it('Is ACTIVE before auction is canceled', async () => {
                        const partyStatus = await partyBid.partyStatus();
                        expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_ACTIVE);
                    });

                    it('Allows artist to cancel auction', async () => {
                        await expect(cancelAuction(artistSigner, market, auctionId, marketName)).to.not.be.reverted;
                    });

                    it('Is ACTIVE before PartyBid-level Finalize', async () => {
                        const partyStatus = await partyBid.partyStatus();
                        expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_ACTIVE);
                    });

                    it('Allows PartyBid Finalize after auction is canceled', async () => {
                        // finalize auction
                        await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');
                    });

                    it(`Is LOST after Finalize`, async () => {
                        const partyStatus = await partyBid.partyStatus();
                        expect(partyStatus).to.equal(PARTY_STATUS.AUCTION_LOST);
                    });

                    it(`Does not own the NFT`, async () => {
                        const owner = await nftContract.ownerOf(tokenId);
                        expect(owner).to.not.equal(partyBid.address);
                    });

                    it('Has zero totalSpent', async () => {
                        const totalSpent = await partyBid.totalSpent();
                        expect(totalSpent).to.equal(0);
                    });

                    it(`Did not transfer fee to multisig`, async () => {
                        const multisigBalanceAfter = await provider.getBalance(
                            partyDAOMultisig.address,
                        );
                        expect(multisigBalanceAfter).to.equal(multisigBalanceBefore);
                    });

                    for (let claim of claims[marketName]) {
                        const { signerIndex, totalContributed } = claim;
                        const contributor = signers[signerIndex];
                        it(`Allows contributors to claim the total they contributed`, async () => {
                            const partyBidBalanceBefore = await provider.getBalance(
                                partyBid.address,
                            );

                            // claim succeeds; event is emitted
                            await expect(partyBid.claim(contributor.address))
                                .to.emit(partyBid, 'Claimed')
                                .withArgs(
                                    contributor.address,
                                    eth(totalContributed),
                                    eth(totalContributed),
                                    eth(0),
                                );

                            const partyBidBalanceAfter = await provider.getBalance(
                                partyBid.address,
                            );

                            // ETH was transferred from PartyBid to contributor
                            await expect(weiToEth(partyBidBalanceAfter)).to.equal(
                                weiToEth(partyBidBalanceBefore) - totalContributed,
                            );
                        });
                    }
                });
            });
        });
    });
});
