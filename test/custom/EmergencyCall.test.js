// SPDX-License-Identifier: MIT
// ============ External Imports ============
const { waffle } = require('hardhat');
const { provider } = waffle;
const { expect } = require('chai');
// ============ Internal Imports ============
const {
    encodeData,
    emergencyCall,
} = require('../helpers/utils');
const { deployTestContractSetup } = require('../helpers/deploy');
const { MARKET_NAMES } = require('../helpers/constants');

describe('Emergency Call', async () => {
    // instantiate test vars
    let partyBid,
        nftContract,
        partyDAOMultisig,
        calldata,
        tokenOwner;
    const signers = provider.getWallets();
    const tokenId = 100;
    const transferTokenId = 200;
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
        partyDAOMultisig = contracts.partyDAOMultisig;
        nftContract = contracts.nftContract;

        // mint the NFT to the PartyBid contract
        await nftContract.mintTo(partyBid.address, transferTokenId);

        // encode calldata to withdraw NFT
        calldata = encodeData(nftContract, 'transferFrom', [partyBid.address, partyDAOMultisig.address, transferTokenId]);

        tokenOwner = await nftContract.ownerOf(transferTokenId);
    });

    it('NFT is in PartyBid before non-multisig call', async () => {
        // NFT is in PartyBid before
        expect(tokenOwner).to.equal(partyBid.address);
    });

    it('Non-multisig call does revert', async () => {
        await expect(emergencyCall(partyBid, signers[1], nftContract.address, calldata)).to.be.revertedWith("PartyBid:: only PartyDAO multisig");
        await expect(emergencyCall(partyBid, signers[2], nftContract.address, calldata)).to.be.revertedWith("PartyBid:: only PartyDAO multisig");
    });

    it('NFT is in PartyBid after non-multisig call', async () => {
        // NFT is in PartyBid before
        tokenOwner = await nftContract.ownerOf(transferTokenId);
        expect(tokenOwner).to.equal(partyBid.address);
    });

    it('Multisig call does not revert', async () => {
        await expect(emergencyCall(partyBid, signers[0], nftContract.address, calldata)).to.emit(nftContract, "Transfer");
    });

    it('NFT is in PartyDAO multisig after multisig call', async () => {
        // NFT is in PartyBid before
        tokenOwner = await nftContract.ownerOf(transferTokenId);
        expect(tokenOwner).to.equal(partyDAOMultisig.address);
    });
});
