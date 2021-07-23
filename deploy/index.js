const {ethers} = require("hardhat");
const fs = require("fs");
const dotenv = require('dotenv');

deployChain()
    .then(() => {
        console.log("DONE");
        process.exit(0);
    })
    .catch(e => {
        console.error(e);
        process.exit(1);
    });

async function deployChain() {
    // load .env
    dotenv.config();
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = process.env;
    if (!(CHAIN_NAME && RPC_ENDPOINT && DEPLOYER_PRIVATE_KEY)) {
        throw new Error("Must populate all values in .env - see .env.example for full list");
    }

    // load config.json
    const config = JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
    const {partyDAOMultisig, factionalArtERC721VaultFactory, weth, foundationMarket, zoraAuctionHouse, initializeParameters} = config;

    console.log(`Deploying ${CHAIN_NAME}`);

    // setup JSON-RPC provider & deployer wallet
    const provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    const deployer = new ethers.Wallet(`0x${DEPLOYER_PRIVATE_KEY}`, provider);

    // Deploy Foundation Market Wrapper
    console.log(`Deploy Foundation Market Wrapper`);
    const foundationMarketWrapper = await deploy(deployer,'FoundationMarketWrapper', [foundationMarket]);
    console.log(`Deployed Foundation Market Wrapper: `, foundationMarketWrapper.address);

    // Deploy Zora Market Wrapper
    console.log(`Deploy Zora Market Wrapper`);
    const zoraMarketWrapper = await deploy(deployer,'ZoraMarketWrapper', [zoraAuctionHouse]);
    console.log(`Deployed Zora Market Wrapper: `, zoraMarketWrapper.address);

    // Deploy PartyBid Factory
    console.log(`Deploy PartyBid Factory`);
    const factory = await deploy(deployer,'PartyBidFactory', [
        partyDAOMultisig,
        factionalArtERC721VaultFactory,
        weth,
    ]);
    console.log(`Deployed PartyBid Factory: `, factory.address);

    // Get PartyBidLogic address
    const logic = await factory.logic();

    console.log(`Initialize Logic Contract`);
    // Initialize PartyBid logic contract
    await initializeLogicContract(logic, zoraMarketWrapper, initializeParameters, deployer);
    console.log(`Initialized Logic Contract`);

    console.log(`Write addresses to ${filename}`);
    // write contract addresses to file
    const addresses = {
        chain: CHAIN_NAME,
        partyBidFactory: factory.address,
        partyBidLogic: logic,
        marketWrappers: {
            foundation: foundationMarketWrapper.address,
            zora: zoraMarketWrapper.address
        }
    };
    const directory = "./deploy/deployed-contracts";
    const filename = `${directory}/${CHAIN_NAME}.json`;
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(
        filename,
        JSON.stringify(addresses, null, 2),
    );
    console.log(`Addresses written to ${filename}`);
}

async function initializeLogicContract(logicAddress, zoraMarketWrapper, initializeParameters, wallet) {
    const {nftContract, tokenId, zoraAuctionId} = initializeParameters;

    const PartyBid = await ethers.getContractFactory("PartyBid", wallet);
    const logic = new ethers.Contract(logicAddress, PartyBid.interface , wallet);

    return logic.initialize(
        zoraMarketWrapper.address,
        nftContract,
        tokenId,
        zoraAuctionId,
        "PartyBid",
        "BID"
    );
}

async function deploy(wallet, name, args = []) {
    const Implementation = await ethers.getContractFactory(name, wallet);
    const contract = await Implementation.deploy(...args);
    const deployedContract = await contract.deployed();
    await contract.deployTransaction.wait(5);
    return deployedContract;
}

