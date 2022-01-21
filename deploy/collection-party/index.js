const {loadConfig, loadEnv, getDeployedAddresses, writeDeployedAddresses} = require("../helpers");
const { getDeployer, deploy } = require("../ethersHelpers");

deployCollectionPartyFactory()
  .then(() => {
    console.log("DONE");
    process.exit(0);
  })
  .catch(e => {
    console.error(e);
    process.exit(1);
  });

async function deployCollectionPartyFactory() {
  // load .env
  const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = loadEnv();

  // load config.json
  const config = loadConfig(CHAIN_NAME);
  const {partyDAOMultisig, fractionalArtERC721VaultFactory, weth} = config;
  if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth)) {
    throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, logicNftContract, logicTokenId");
  }

  // get the deployed contracts
  const {directory, filename, contractAddresses} = getDeployedAddresses("collection-party", CHAIN_NAME);
  const {allowList} = contractAddresses;
  // setup deployer wallet
  const deployer = getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY);

  // Deploy Factory
  console.log(`Deploy CollectionParty Factory to ${CHAIN_NAME}`);
  const factory = await deploy(deployer,'CollectionPartyFactory', [
    partyDAOMultisig,
    fractionalArtERC721VaultFactory,
    weth,
    allowList
  ]);
  console.log(`Deployed CollectionParty Factory to ${CHAIN_NAME}: `, factory.address);

  // Get logic address
  const logic = await factory.logic();

  // update the addresses
  contractAddresses["collectionPartyFactory"] = factory.address;
  contractAddresses["collectionPartyLogic"] = logic;

  // write the updated object
  writeDeployedAddresses(directory, filename, contractAddresses);

  console.log(`CollectionParty Factory and Logic written to ${filename}`);
}
