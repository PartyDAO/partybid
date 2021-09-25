// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const { eth, getBalances, bidThroughParty, contribute, placeBid } = require('../helpers/utils');
const { deployTestContractSetup, getTokenVault } = require('../helpers/deploy');
const {
    MARKETS,
    FOURTY_EIGHT_HOURS_IN_SECONDS,
} = require('../helpers/constants');
const { testCases } = require('../testCases.json');

describe('Mix Contribute and Bid', async () => {
    MARKETS.map((marketName) => {
        describe(marketName, async () => {
            const testCase = testCases[0];
            // get test case information
            const { auctionReservePrice, contributions, bids, claims } = testCase;
            // instantiate test vars
            let partyBid, market, auctionId, token;
            const signers = provider.getWallets();
            const firstSigner = signers[0];
            const tokenId = 100;

            before(async () => {
                // DEPLOY NFT, MARKET, AND PARTY BID CONTRACTS
                const contracts = await deployTestContractSetup(
                    marketName,
                    provider,
                    firstSigner,
                    tokenId,
                    auctionReservePrice,
                );
                partyBid = contracts.partyBid;
                market = contracts.market;

                auctionId = await partyBid.auctionId();

                // submit contributions 0 and 1
                for (let i = 0; i < 2; i ++) {
                    const { signerIndex, amount } = contributions[i];
                    const signer = signers[signerIndex];
                    await contribute(partyBid, signer, eth(amount));
                }

                // submit bid 0 via partyBid
                const { signerIndex } = contributions[0];
                await bidThroughParty(partyBid, signers[signerIndex]);

                // submit contributions 0 and 1
                for (let i = 2; i < 4; i ++) {
                    const { signerIndex, amount } = contributions[i];
                    await contribute(partyBid, signers[signerIndex], eth(amount));
                }

                // submit bids 1 and 2
                for (let i = 1; i < 3; i ++) {
                    const { placedByPartyBid, amount, success } = bids[i];
                    if (success && placedByPartyBid) {
                        const { signerIndex } = contributions[0];
                        await bidThroughParty(partyBid, signers[signerIndex]);
                    } else if (success && !placedByPartyBid) {
                        await placeBid(
                            firstSigner,
                            market,
                            auctionId,
                            eth(amount),
                            marketName,
                        );
                    }
                }
            });

            it('Allows Finalize', async () => {
                // increase time on-chain so that auction can be finalized
                await provider.send('evm_increaseTime', [
                    FOURTY_EIGHT_HOURS_IN_SECONDS,
                ]);
                await provider.send('evm_mine');

                // finalize auction
                await expect(partyBid.finalize()).to.emit(partyBid, 'Finalized');
                token = await getTokenVault(partyBid, firstSigner);
            });

            for (let claim of claims[marketName]) {
                const { signerIndex, tokens, excessEth, totalContributed } = claim;
                const contributor = signers[signerIndex];
                it(`Allows Claim, transfers ETH and tokens to contributors after Finalize`, async () => {
                    const accounts = [
                        {
                            name: 'partyBid',
                            address: partyBid.address,
                        },
                        {
                            name: 'contributor',
                            address: contributor.address,
                        },
                    ];

                    const before = await getBalances(provider, token, accounts);

                    // signer has no PartyBid tokens before claim
                    expect(before.contributor.tokens).to.equal(0);

                    // claim succeeds; event is emitted
                    await expect(partyBid.claim(contributor.address))
                        .to.emit(partyBid, 'Claimed')
                        .withArgs(
                            contributor.address,
                            eth(totalContributed),
                            eth(excessEth),
                            eth(tokens),
                        );

                    const after = await getBalances(provider, token, accounts);

                    // ETH was transferred from PartyBid to contributor
                    await expect(after.partyBid.eth).to.equal(
                        before.partyBid.eth - excessEth
                    );
                    // TODO: fix this test (hardhat gasPrice zero not working)
                    // await expect(after.contributor.eth).to.equal(
                    //   before.contributor.eth + excessEth,
                    // );

                    // Tokens were transferred from PartyBid to contributor
                    await expect(after.partyBid.tokens).to.equal(
                        before.partyBid.tokens - tokens,
                    );
                    await expect(after.contributor.tokens).to.equal(
                        before.contributor.tokens + tokens,
                    );
                });
            }
        });
    });
});
