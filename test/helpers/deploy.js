const { eth, approve, createReserveAuction } = require('./utils');

async function deploy(name, args = []) {
  const Implementation = await ethers.getContractFactory(name);
  const contract = await Implementation.deploy(...args);
  return contract.deployed();
}

async function deployPartyBid(
  partyDAOMultisig,
  whitelist,
  market,
  nftContract,
  tokenId = 100,
  auctionId = 1,
  quorumPercent = 90,
  tokenName = 'Party',
  tokenSymbol = 'PARTY',
) {
  return deploy('PartyBid', [
    partyDAOMultisig,
    whitelist,
    market,
    nftContract,
    tokenId,
    auctionId,
    quorumPercent,
    tokenName,
    tokenSymbol,
  ]);
}

async function deployFoundationMarket() {
  const foundationTreasury = await deploy('MockFoundationTreasury');
  const foundationMarket = await deploy('FNDNFTMarket');
  await foundationMarket.initialize(foundationTreasury.address);
  await foundationMarket.adminUpdateConfig(1000, 86400, 0, 0, 0);
  return foundationMarket;
}

async function getTokenVault(partyBid, signer) {
  const vaultAddress = await partyBid.tokenVault();
  const TokenVault = await ethers.getContractFactory('TokenVault');
  return new ethers.Contract(vaultAddress, TokenVault.interface, signer);
}

async function getPartyBidContractFromEventLogs(
  provider,
  factory,
  artistSigner,
) {
  // get logs emitted from PartyBid Factory
  const logs = await provider.getLogs({ address: factory.address });

  // parse events from logs
  const PartyBidFactory = await ethers.getContractFactory('PartyBidFactory');
  const events = logs.map((log) => PartyBidFactory.interface.parseLog(log));

  // extract PartyBid proxy address from PartyBidDeployed log
  const partyBidProxyAddress = events[0]['args'][0];

  // instantiate ethers contract with PartyBid Logic interface + proxy address
  const PartyBid = await ethers.getContractFactory('PartyBid');
  const partyBid = new ethers.Contract(
    partyBidProxyAddress,
    PartyBid.interface,
    artistSigner,
  );
  return partyBid;
}

async function deployTestContractSetup(
  provider,
  artistSigner,
  tokenId = 100,
  reservePrice = 1,
) {
  // Deploy WETH
  const weth = await deploy('EtherToken');

  // Deploy NFT Contract & Mint Token
  const nftContract = await deploy('TestERC721');
  await nftContract.mint(artistSigner.address, tokenId);

  // Deploy Foundation Market and Market Wrapper Contract
  const foundationMarket = await deployFoundationMarket();
  const marketWrapper = await deploy('FoundationMarketWrapper', [
    foundationMarket.address,
  ]);

  // Approve NFT Transfer to Foundation Market
  await approve(artistSigner, nftContract, foundationMarket.address, tokenId);

  // Create Foundation Reserve Auction
  await createReserveAuction(
    artistSigner,
    foundationMarket,
    nftContract.address,
    tokenId,
    eth(reservePrice),
  );
  const auctionId = 1;

  // Deploy PartyDAO multisig
  const partyDAOMultisig = await deploy('PayableContract');

  const tokenVaultSettings = await deploy('Settings');
  const tokenVaultFactory = await deploy('ERC721VaultFactory', [
    tokenVaultSettings.address,
  ]);

  // Deploy PartyBid Factory (including PartyBid Logic + Reseller Whitelist)
  const factory = await deploy('PartyBidFactory', [
    partyDAOMultisig.address,
    tokenVaultFactory.address,
    weth.address,
  ]);

  // Deploy PartyBid proxy
  await factory.startParty(
    marketWrapper.address,
    nftContract.address,
    tokenId,
    auctionId,
    'Parrrrti',
    'PRTI',
  );

  // Get PartyBid ethers contract
  const partyBid = await getPartyBidContractFromEventLogs(
    provider,
    factory,
    artistSigner,
  );

  return {
    nftContract,
    market: foundationMarket,
    partyBid,
    partyDAOMultisig,
  };
}

module.exports = {
  deployPartyBid,
  getTokenVault,
  deployTestContractSetup,
  deployFoundationMarket,
  deploy,
};
