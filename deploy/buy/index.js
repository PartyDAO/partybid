const {ethers} = require("hardhat");
const {BigNumber} = ethers;
const fs = require("fs");
const dotenv = require('dotenv');
const {getDeployedAddresses, writeDeployedAddresses} = require("./helpers");

const GAS_PRICE = "70000000000";

deployPartyBuyFactory()
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

async function deployPartyBuyFactory() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = JSON.parse(fs.readFileSync(`./deploy/buy/configs/${CHAIN_NAME}.json`));
    const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth, allowedContracts, logicNftContract, logicTokenId} = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth && allowedContracts && logicNftContract && logicTokenId)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, logicNftContract, logicTokenId");
    }

    // get the deployed Zora MarketWrapper
    const {directory, filename, contractAddresses} = getDeployedAddresses(CHAIN_NAME);
    // setup deployer wallet
    const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

    //  Deploy AllowList
    console.log(`Deploy AllowList to ${CHAIN_NAME}`);
    const allowList = await deploy(deployer, 'AllowList');
    console.log(`Deployed AllowList to ${CHAIN_NAME}`);

    // Deploy PartyBid Factory
    console.log(`Deploy PartyBuy Factory to ${CHAIN_NAME}`);
    const factory = await deploy(deployer,'PartyBuyFactory', [
        partyDAOMultisig,
        fractionalArtERC721VaultFactory,
        weth,
        allowList.address,
        logicNftContract,
        logicTokenId,
    ]);
    console.log(`Deployed PartyBuy Factory to ${CHAIN_NAME}: `, factory.address);

    // Setup Allowed Contracts
    for (let allowedContract of allowedContracts) {
        console.log(`Set Allowed ${allowedContract}`);
        await allowList.setAllowed(allowedContract, true);
    }

    // Transfer Ownership  of AllowList to PartyDAO multisig
    if (CHAIN_NAME == "mainnet") {
        console.log(`Transfer Ownership of AllowList on ${CHAIN_NAME}`);
        await allowList.transferOwnership(partyDAOMultisig);
        console.log(`Transferred Ownership of AllowList on ${CHAIN_NAME}`);
    }

    // Get PartyBidLogic address
    const logic = await factory.logic();

    // update the foundation market wrapper address
    contractAddresses["partyBuyFactory"] = factory.address;
    contractAddresses["partyBuyLogic"] = logic;
    contractAddresses["allowList"] = allowList.address;

    // write the updated object
    writeDeployedAddresses(directory, filename, contractAddresses);

    console.log(`PartyBuy Factory and Logic written to ${filename}`);
}

async function deploy(wallet, name, args = []) {
    const Implementation = await ethers.getContractFactory(name, wallet);
    const contract = await Implementation.deploy(...args, {
        gasPrice: BigNumber.from(GAS_PRICE),
        gasLimit: 5000000
    });
    return contract.deployed();
}
