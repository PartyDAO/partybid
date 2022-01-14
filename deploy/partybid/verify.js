const {getDeployedAddresses, verifyContract, loadEnv, loadConfig } = require("../helpers");

async function verify() {
    // load .env
    const {CHAIN_NAME} = loadEnv();
    // load config
    const config = loadConfig(CHAIN_NAME);
    const {
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth,
        foundationMarket,
        zoraAuctionHouse,
        nounsAuctionHouse,
    } = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth && foundationMarket && zoraAuctionHouse && nounsAuctionHouse)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, foundationMarket, zoraAuctionHouse");
    }

    // load deployed contracts
    const {contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);
    const {partyBidFactory, partyBidLogic, marketWrappers} = contractAddresses;
    const {foundation, zora, nouns, koans} = marketWrappers;

    console.log(`Verifying ${CHAIN_NAME}`);

    // Verify PartyBid Factory
    console.log(`Verify PartyBid Factory`);
    await verifyContract(partyBidFactory, [
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth
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

    // Verify Koans Market Wrapper
    console.log(`Verify Koans Market Wrapper`);
    await verifyContract(koans, [koansAuctionHouse]);
}

module.exports = {
    verify
};
