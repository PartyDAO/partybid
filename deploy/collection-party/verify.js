const {getDeployedAddresses, verifyContract, loadEnv, loadConfig } = require("../helpers");

async function verify() {
  // load .env
  const {CHAIN_NAME} = loadEnv()
  // load config
  const config = loadConfig(CHAIN_NAME);
  const {
    partyDAOMultisig,
    fractionalArtERC721VaultFactory,
    weth
  } = config;
  if (!(partyDAOMultisig && fractionalArtERC721VaultFactory && weth)) {
    throw new Error("Must populate config with partyDAOMultisig, fractionalArtERC721VaultFactory, weth, foundationMarket, zoraAuctionHouse, logicNftContract, logicTokenId, logicZoraAuctionId");
  }

  // load deployed contracts
  const {contractAddresses} = getDeployedAddresses("collection-party", CHAIN_NAME);
  const {collectionPartyFactory, collectionPartyLogic, allowList} = contractAddresses;

  console.log(`Verifying ${CHAIN_NAME}`);

  console.log(`Verify CollectionParty Factory`);
  await verifyContract(collectionPartyFactory, [
    partyDAOMultisig,
    fractionalArtERC721VaultFactory,
    weth,
    allowList
  ]);

  console.log(`Verify CollectionParty Logic`);
  await verifyContract(collectionPartyLogic, [partyDAOMultisig, fractionalArtERC721VaultFactory, weth, allowList]);
}

module.exports = {
  verify
};
