const {loadConfig, loadEnv, getDeployedAddresses, writeDeployedAddresses} = require("../helpers");
const { getDeployer, deploy } = require("../ethersHelpers");

deployPartyBuyFactory()
    .then(() => {
        console.log("DONE");
        process.exit(0);
    })
    .catch(e => {
        console.error(e);
        process.exit(1);
    });

async function deployPartyBuyFactory() {
    // load .env
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

    // load config.json
    const config = loadConfig(CHAIN_NAME);
    const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth, allowedContracts} = config;
    if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth && allowedContracts)) {
        throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, logicNftContract, logicTokenId");
    }

    // get the deployed contracts
    const {directory, filename, contractAddresses} = getDeployedAddresses('partybuy', CHAIN_NAME);
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
        allowList.address
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
