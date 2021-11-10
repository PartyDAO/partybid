const { deploy, getTokenVault } = require('../../helpers/deploy');

async function deployTestContractSetup(
  provider,
  artistSigner,
  maxPrice,
  secondsToTimeout,
  splitRecipient,
  splitBasisPoints,
  tokenId,
  fakeMultisig = false,
) {
  // Deploy WETH
  const weth = await deploy('EtherToken');

  // For other markets, deploy the test NFT Contract
  const nftContract = await deploy('TestERC721', []);
  // Mint token to artist
  await nftContract.mint(artistSigner.address, tokenId);

  // Deploy PartyDAO multisig
  let partyDAOMultisig;
  if(!fakeMultisig) {
    partyDAOMultisig = await deploy('PayableContract');
  } else {
    partyDAOMultisig = artistSigner;
  }

  const tokenVaultSettings = await deploy('Settings');
  const tokenVaultFactory = await deploy('ERC721VaultFactory', [
    tokenVaultSettings.address,
  ]);

  // Deploy PartyBid Factory (including PartyBid Logic + Reseller Whitelist)
  const factory = await deploy('PartyBuyFactory', [
    partyDAOMultisig.address,
    tokenVaultFactory.address,
    weth.address,
    nftContract.address,
    tokenId,
  ]);

  // Deploy PartyBid proxy
  await factory.startParty(
    nftContract.address,
    tokenId,
    maxPrice,
    secondsToTimeout,
    splitRecipient,
    splitBasisPoints,
    'Parrrrti',
    'PRTI',
  );

  // Get PartyBid ethers contract
  const partyBuy = await getPartyBuyContractFromEventLogs(
    provider,
    factory,
    artistSigner,
  );

  return {
    nftContract,
    partyBuy,
    partyDAOMultisig,
    weth,
  };
}

async function getPartyBuyContractFromEventLogs(
  provider,
  factory,
  artistSigner,
) {
  // get logs emitted from PartyBid Factory
  const logs = await provider.getLogs({ address: factory.address });

  // parse events from logs
  const PartyBuyFactory = await ethers.getContractFactory('PartyBuyFactory');
  const events = logs.map((log) => PartyBuyFactory.interface.parseLog(log));

  // extract proxy address from PartyBuyDeployed log
  const proxyAddress = events[0]['args'][0];

  // instantiate ethers contract with PartyBid Logic interface + proxy address
  const PartyBuy = await ethers.getContractFactory('PartyBuy');
  const partyBuy = new ethers.Contract(
    proxyAddress,
    PartyBuy.interface,
    artistSigner,
  );
  return partyBuy;
}

module.exports = {
  deployTestContractSetup,
  getTokenVault,
};
