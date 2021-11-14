const fs = require("fs");
const dotenv = require('dotenv');
dotenv.config();
const {getDeployedAddresses} = require("./helpers");

async function verify() {
    // load .env
    const {CHAIN_NAME} = process.env;
    if (!(CHAIN_NAME) ) {
        throw new Error("Must add chain name to .env");
    } else if(hre.network.name != CHAIN_NAME) {
        throw new Error(`CHAIN_NAME in .env file is "${CHAIN_NAME}" but hardhat --network in package.json is "${hre.network.name}; change them to match"`)
    }

    // load config
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
    const {
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth,
        foundationMarket,
        zoraAuctionHouse,
        nounsAuctionHouse,
        logicNftContract,
        logicTokenId,
        logicZoraAuctionId
    } = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth && foundationMarket && zoraAuctionHouse && nounsAuctionHouse && logicNftContract && logicTokenId && logicZoraAuctionId)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, foundationMarket, zoraAuctionHouse, logicNftContract, logicTokenId, logicZoraAuctionId");
    }

    // load deployed contracts
    const {contractAddresses} = getDeployedAddresses(CHAIN_NAME);
    if (!contractAddresses["marketWrappers"]["zora"]) {
        throw new Error("No deployed Zora MarketWrapper for chain");
    }
    const {partyBidFactory, partyBidLogic, marketWrappers} = contractAddresses;
    const {foundation, zora, nouns} = marketWrappers;

    console.log(`Verifying ${CHAIN_NAME}`);

    // Verify PartyBid Factory
    console.log(`Verify PartyBid Factory`);
    await verifyContract(partyBidFactory, [
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth,
        zora,
        logicNftContract,
        logicTokenId,
        logicZoraAuctionId
    ]);

    // Verify PartyBid Logic
    console.log(`Verify PartyBid Logic`);
    await verifyContract(partyBidLogic, [partyDAOMultisig, fractionalArtERC721VaultFactory, weth]);

    // Verify Foundation Market Wrapper
    console.log(`Verify Foundation Market Wrapper`);
    await verifyContract(foundation, [foundationMarket]);

    // Verify Zora Market Wrapper
    console.log(`Verify Zora Market Wrapper`);
    await verifyContract(zora, [zoraAuctionHouse]);

    // Verify Nouns Market Wrapper
    console.log(`Verify Nouns Market Wrapper`);
    await verifyContract(nouns, [nounsAuctionHouse]);
}

/*
 * Given one contract verification input,
 * attempt to verify the contracts' source code on Etherscan
 * */
async function verifyContract(address, constructorArguments) {
    const {CHAIN_NAME} = process.env;
    try {
        await hre.run('verify:verify', {
            network: CHAIN_NAME,
            address,
            constructorArguments,
        });
    } catch (e) {
        console.error(e);
    }
    console.log('\n\n'); // add space after each attempt
}

module.exports = {
    verify
};
