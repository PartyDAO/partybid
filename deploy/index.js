const {ethers} = require("hardhat");
const fs = require("fs");
const dotenv = require('dotenv');
const {getDeployedAddresses, writeDeployedAddresses} = require("./helpers");

deployChain()
    .then(() => {
        console.log("DONE");
        process.exit(0);
    })
    .catch(e => {
        console.error(e);
        process.exit(1);
    });

function loadEnv() {
    dotenv.config();
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = process.env;
    if (!(CHAIN_NAME && RPC_ENDPOINT && DEPLOYER_PRIVATE_KEY)) {
        throw new Error("Must populate all values in .env - see .env.example for full list");
    }
    return {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY};
}

function getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY) {
    const provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    const deployer = new ethers.Wallet(`0x${DEPLOYER_PRIVATE_KEY}`, provider);
    return deployer;
}

async function deployZoraMarketWrapper() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
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
    let {directory, filename, contractAddresses} = getDeployedAddresses(CHAIN_NAME);

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
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
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
    let {directory, filename, contractAddresses} = getDeployedAddresses(CHAIN_NAME);

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

async function deployPartyBidFactory() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
    const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth, logicNftContract, logicTokenId, logicZoraAuctionId} = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth && logicNftContract && logicTokenId && logicZoraAuctionId)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, logicNftContract, logicTokenId, logicZoraAuctionId");
    }

    // get the deployed Zora MarketWrapper
    const {directory, filename, contractAddresses} = getDeployedAddresses(CHAIN_NAME);
    if (!contractAddresses["marketWrappers"]["zora"]) {
        throw new Error("No deployed Zora MarketWrapper for chain");
    }

    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    // Deploy PartyBid Factory
    console.log(`Deploy PartyBid Factory to ${CHAIN_NAME}`);
    const factory = await deploy(deployer,'PartyBidFactory', [
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth,
        contractAddresses["marketWrappers"]["zora"],
        logicNftContract,
        logicTokenId,
        logicZoraAuctionId
    ]);
    console.log(`Deployed PartyBid Factory to ${CHAIN_NAME}: `, factory.address);

    // Get PartyBidLogic address
    const logic = await factory.logic();

    // update the foundation market wrapper address
    contractAddresses["partyBidFactory"] = factory.address;
    contractAddresses["partyBidLogic"] = logic;

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`PartyBid Factory and Logic written to ${filename}`);
}


async function deployChain() {
    await deployZoraMarketWrapper();
    await deployFoundationMarketWrapper();
    await deployPartyBidFactory();
}

async function deploy(wallet, name, args = []) {
    const Implementation = await ethers.getContractFactory(name, wallet);
    const contract = await Implementation.deploy(...args);
    return contract.deployed();
}