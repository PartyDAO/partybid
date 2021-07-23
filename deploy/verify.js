const fs = require("fs");
const dotenv = require('dotenv');
dotenv.config();

async function verify() {
    // load .env
    const {CHAIN_NAME} = process.env;
    if (!(CHAIN_NAME) ) {
        throw new Error("Must add chain name to .env");
    }

    // load config
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
    const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth, foundationMarket, zoraAuctionHouse} = config;

    // load deployed contracts
    const contracts = JSON.parse(fs.readFileSync(`./deploy/deployed-contracts/${CHAIN_NAME}.json`));
    const {partyBidFactory, partyBidLogic, marketWrappers} = contracts;
    const {foundation, zora} = marketWrappers;

    console.log(`Verifying ${CHAIN_NAME}`);

    // Verify PartyBid Factory
    console.log(`Verify PartyBid Factory`);
    await verifyContract(partyBidFactory, [partyDAOMultisig, fractionalArtERC721VaultFactory, weth]);

    // Verify PartyBid Logic
    console.log(`Verify PartyBid Logic`);
    await verifyContract(partyBidLogic, [partyDAOMultisig, fractionalArtERC721VaultFactory, weth]);

    // Verify Foundation Market Wrapper
    console.log(`Verify Foundation Market Wrapper`);
    await verifyContract(foundation, [foundationMarket]);

    // Verify Zora Market Wrapper
    console.log(`Verify Zora Market Wrapper`);
    await verifyContract(zora, [zoraAuctionHouse]);
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

