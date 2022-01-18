const {loadConfig, loadEnv, getDeployedAddresses, writeDeployedAddresses} = require("../helpers");
const { getDeployer, deploy } = require("../ethersHelpers");

deployPartyBidFactory()
    .then(() => {
        console.log("DONE");
        process.exit(0);
    })
    .catch(e => {
        console.error(e);
        process.exit(1);
    });

async function deployZoraMarketWrapper() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {zoraAuctionHouse} = config;
    if (!zoraAuctionHouse) {
        throw new Error("Must populate config with Zora Auction House address");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy Zora Market Wrapper
    console.log(`Deploy Zora Market Wrapper to ${CHAIN_NAME}`);
    const zoraMarketWrapper = await deploy(deployer,'ZoraMarketWrapper', [zoraAuctionHouse]);
    console.log(`Deployed Zora Market Wrapper to ${CHAIN_NAME}: `, zoraMarketWrapper.address);

    // get the existing deployed addresses
    let {directory, filename, contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);

    // update the zora market wrapper address
    if (contractAddresses["marketWrappers"]) {
        contractAddresses["marketWrappers"]["zora"] = zoraMarketWrapper.address;
    } else {
        contractAddresses["marketWrappers"] = {
            zora: zoraMarketWrapper.address
        };
    }

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`Zora Market Wrapper written to ${filename}`);
}

async function deployFoundationMarketWrapper() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {foundationMarket} = config;
    if (!foundationMarket) {
        throw new Error("Must populate config with Foundation Market address");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy Foundation Market Wrapper
    console.log(`Deploy Foundation Market Wrapper to ${CHAIN_NAME}`);
    const foundationMarketWrapper = await deploy(deployer,'FoundationMarketWrapper', [foundationMarket]);
    console.log(`Deployed Foundation Market Wrapper to ${CHAIN_NAME}: `, foundationMarketWrapper.address);

    // get the existing deployed addresses
    let {directory, filename, contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);

    // update the foundation market wrapper address
    if (contractAddresses["marketWrappers"]) {
        contractAddresses["marketWrappers"]["foundation"] = foundationMarketWrapper.address;
    } else {
        contractAddresses["marketWrappers"] = {
            foundation: foundationMarketWrapper.address
        };
    }

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`Foundation Market Wrapper written to ${filename}`);
}

async function deployNounsMarketWrapper() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {nounsAuctionHouse} = config;
    if (!nounsAuctionHouse) {
        throw new Error("Must populate config with Nouns Auction House address");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy Nouns Market Wrapper
    console.log(`Deploy Nouns Market Wrapper to ${CHAIN_NAME}`);
    const nounsMarketWrapper = await deploy(deployer,'NounsMarketWrapper', [nounsAuctionHouse]);
    console.log(`Deployed Nouns Market Wrapper to ${CHAIN_NAME}: `, nounsMarketWrapper.address);

    // get the existing deployed addresses
    let {directory, filename, contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);

    // update the nouns market wrapper address
    if (contractAddresses["marketWrappers"]) {
        contractAddresses["marketWrappers"]["nouns"] = nounsMarketWrapper.address;
    } else {
        contractAddresses["marketWrappers"] = {
            nouns: nounsMarketWrapper.address
        };
    }

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`Nouns Market Wrapper written to ${filename}`);
}

async function deployKoansMarketWrapper() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {koansAuctionHouse} = config;
    if (!koansAuctionHouse) {
        throw new Error("Must populate config with Koans Auction House address");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy Koans Market Wrapper
    console.log(`Deploy Koans Market Wrapper to ${CHAIN_NAME}`);
    const koansMarketWrapper = await deploy(deployer,'KoansMarketWrapper', [koansAuctionHouse]);
    console.log(`Deployed Koans Market Wrapper to ${CHAIN_NAME}: `, koansMarketWrapper.address);

    // get the existing deployed addresses
    let {directory, filename, contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);

    // update the nouns market wrapper address
    if (contractAddresses["marketWrappers"]) {
        contractAddresses["marketWrappers"]["koans"] = koansMarketWrapper.address;
    } else {
        contractAddresses["marketWrappers"] = {
            koans: koansMarketWrapper.address
        };
    }

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`Koans Market Wrapper written to ${filename}`);
}

async function deployPartyBidFactory() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth} = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy PartyBid Factory
    console.log(`Deploy PartyBid Factory to ${CHAIN_NAME}`);
    const factory = await deploy(deployer,'PartyBidFactory', [
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth
    ]);
    console.log(`Deployed PartyBid Factory to ${CHAIN_NAME}: `, factory.address);

    // Get PartyBidLogic address
    const logic = await factory.logic();

    // get the current deployed addresses
    const {directory, filename, contractAddresses} = getDeployedAddresses('partybid', CHAIN_NAME);

    // update the factory & logic addresses
    contractAddresses["partyBidFactory"] = factory.address;
    contractAddresses["partyBidLogic"] = logic;

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`PartyBid Factory and Logic written to ${filename}`);
}


async function deployChain() {
    await deployZoraMarketWrapper();
    await deployFoundationMarketWrapper();
    await deployNounsMarketWrapper();
    await deployPartyBidFactory();
}
