const {
  eth,
  approve,
  createReserveAuction,
  createZoraAuction,
} = require('./utils');
const { MARKET_NAMES, FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./constants');
const { upgrades } = require('hardhat');

async function deployFoundationAndStartAuction(
  artistSigner,
  nftContract,
  tokenId,
  reservePrice,
) {
  // Deploy Foundation treasury & NFT market
  const foundationTreasury = await deploy('MockFoundationTreasury');
  const foundationMarket = await deploy('FNDNFTMarket');

  // initialize / configure Foundation market
  await foundationMarket.initialize(foundationTreasury.address);
  await foundationMarket.adminUpdateConfig(1000, 86400, 0, 0, 0);

  // Deploy Market Wrapper
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

  return {
    market: foundationMarket,
    marketWrapper,
    auctionId,
  };
}

async function deployZoraAndStartAuction(
  artistSigner,
  nftContract,
  tokenId,
  weth,
  reservePrice,
) {
  // Deploy Zora Media / Market
  const zoraMarket = await deploy('Market');
  const zoraMedia = await deploy('Media', [zoraMarket.address]);

  // Deploy Zora Auction House
  const zoraAuctionHouse = await deploy('AuctionHouse', [
    zoraMedia.address,
    weth.address,
  ]);

  // Deploy Market Wrapper
  const marketWrapper = await deploy('ZoraMarketWrapper', [
    zoraAuctionHouse.address,
  ]);

  // Approve NFT Transfer to Market
  await approve(artistSigner, nftContract, zoraAuctionHouse.address, tokenId);

  // Create Zora Auction
  await createZoraAuction(
    artistSigner,
    zoraAuctionHouse,
    tokenId,
    nftContract.address,
    eth(reservePrice),
  );

  const auctionId = 0;

  return {
    market: zoraAuctionHouse,
    marketWrapper,
    auctionId,
  };
}

async function deployNounsToken(tokenId) {
  // Deploy the Nouns mock NFT descriptor
  const nounsDescriptor = await deploy('NounsMockDescriptor', []);

  // Deploy the Nouns mock seed generator
  const nounsSeeder = await deploy('NounsMockSeeder', []);

  // Deploy the Nouns NFT Contract. Note that the Nouns
  // Auction House is responsible for token minting
  return deploy('NounsToken', [
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    nounsDescriptor.address,
    nounsSeeder.address,
    ethers.constants.AddressZero,
    tokenId,
  ]);
}

async function deployKoansToken(tokenId) {
  // Deploy the Koans NFT Contract. Note that the Koans
  // Auction House is responsible for token minting
  return deploy('KoansToken', [
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
    tokenId,
  ]);
}

async function deployNounsAndStartAuction(
  nftContract,
  tokenId,
  weth,
  reservePrice,
  pauseAuctionHouse,
) {
  const TIME_BUFFER = 5 * 60;
  const MIN_INCREMENT_BID_PERCENTAGE = 5;

  // Deploy Nouns Auction House
  const auctionHouseFactory = await ethers.getContractFactory('NounsAuctionHouse');
  const nounsAuctionHouse = await upgrades.deployProxy(auctionHouseFactory, [
    nftContract.address,
    weth.address,
    TIME_BUFFER,
    eth(reservePrice),
    MIN_INCREMENT_BID_PERCENTAGE,
    FOURTY_EIGHT_HOURS_IN_SECONDS,
  ]);

  // Set Nouns Auction House as minter on Nouns NFT contract
  await nftContract.setMinter(nounsAuctionHouse.address);

  // Deploy Market Wrapper
  const marketWrapper = await deploy('NounsMarketWrapper', [
    nounsAuctionHouse.address,
  ]);

  // Start auction
  await nounsAuctionHouse.unpause();

  // If true, pause the auction house after the first Noun is minted
  if (pauseAuctionHouse) {
    await nounsAuctionHouse.pause();
  }

  const { nounId } = await nounsAuctionHouse.auction();

  return {
    market: nounsAuctionHouse,
    marketWrapper,
    auctionId: nounId.toNumber(),
  };
}

async function deployKoansAndStartAuction(
  nftContract,
  tokenId,
  weth,
  reservePrice,
  pauseAuctionHouse,
  offerAddress,
) {
  const TIME_BUFFER = 5 * 60;
  const MIN_INCREMENT_BID_PERCENTAGE = 5;

  // Deploy Sasho token - we never use this but we need it for the AH to settle.
  const sashoToken = await deploy('SashoToken', []);

  // Deploy Koans Auction House.
  const koansAuctionHouse = await deploy('KoansAuctionHouse', [
    nftContract.address,
    sashoToken.address,
    weth.address,
    TIME_BUFFER,
    eth(reservePrice),
    MIN_INCREMENT_BID_PERCENTAGE,
    FOURTY_EIGHT_HOURS_IN_SECONDS,
    ethers.constants.AddressZero,
    ethers.constants.AddressZero,
  ]);

  // Set Koans Auction House as the owner of Sashos.
  await sashoToken.transferOwnership(koansAuctionHouse.address);

  // Create a mock Offer contract for adding 'winning' offers to the auction queue.
  const offer = await deploy('MockOffer', [koansAuctionHouse.address]);

  // Set Koans Auction House as minter on Koans NFT contract
  await nftContract.setMinter(koansAuctionHouse.address);

  // Set the Offer contract on the auction house to the mock offer we deployed.
  await koansAuctionHouse.setOfferAddress(offer.address);

  for (let i = 0; i < 96; ++i) {
    await offer.addOffer("mock_uri", ethers.constants.AddressZero);
  }

  // Deploy Market Wrapper
  const marketWrapper = await deploy('KoansMarketWrapper', [
    koansAuctionHouse.address,
  ]);

  // Start auction
  await koansAuctionHouse.unpause();

  // If true, pause the auction house after the first Koan is minted
  if (pauseAuctionHouse) {
    await koansAuctionHouse.pause();
  }

  const { koanId } = await koansAuctionHouse.auction();

  return {
    market: koansAuctionHouse,
    marketWrapper,
    auctionId: koanId.toNumber(),
  };
}

async function deployTestContractSetup(
  marketName,
  provider,
  artistSigner,
  splitRecipient,
  splitBasisPoints,
  reservePrice,
  tokenId,
  fakeMultisig = false,
  pauseAuctionHouse = false,
) {
  // Deploy WETH
  const weth = await deploy('EtherToken');

  // Nouns uses a custom ERC721 contract. Note that the Nouns
  // Auction House is responsible for token minting
  let nftContract;
  if (marketName == MARKET_NAMES.NOUNS) {
    // for Nouns, deploy custom Nouns NFT contract
    nftContract = await deployNounsToken(tokenId);
  } else if (marketName == MARKET_NAMES.KOANS) {
    // for Koans, deploy custom Koans NFT contract.
    nftContract = await deployKoansToken(tokenId);
  } else {
    // For other markets, deploy the test NFT Contract
    nftContract = await deploy('TestERC721', []);

    // Mint token to artist
    await nftContract.mint(artistSigner.address, tokenId);
  }

  // Deploy Market and Market Wrapper Contract + Start Auction
  let marketContracts;
  if (marketName == MARKET_NAMES.FOUNDATION) {
    marketContracts = await deployFoundationAndStartAuction(
      artistSigner,
      nftContract,
      tokenId,
      reservePrice,
    );
  } else if (marketName == MARKET_NAMES.ZORA) {
    marketContracts = await deployZoraAndStartAuction(
      artistSigner,
      nftContract,
      tokenId,
      weth,
      reservePrice,
    );
  } else if (marketName == MARKET_NAMES.NOUNS) {
    marketContracts = await deployNounsAndStartAuction(
      nftContract,
      tokenId,
      weth,
      reservePrice,
      pauseAuctionHouse,
    )
  } else if (marketName == MARKET_NAMES.KOANS) {
    marketContracts = await deployKoansAndStartAuction(
      nftContract,
      tokenId,
      weth,
      reservePrice,
      pauseAuctionHouse,
    )
  } else {
    throw new Error('Unsupported market type');
  }

  const { market, marketWrapper, auctionId } = marketContracts;

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
  const factory = await deploy('PartyBidFactory', [
    partyDAOMultisig.address,
    tokenVaultFactory.address,
    weth.address,
    marketWrapper.address,
    nftContract.address,
    tokenId,
    auctionId
  ]);

  // Deploy PartyBid proxy
  await factory.startParty(
    marketWrapper.address,
    nftContract.address,
    tokenId,
    auctionId,
    splitRecipient,
    splitBasisPoints,
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
    market,
    marketWrapper,
    partyBid,
    partyDAOMultisig,
    weth,
  };
}

async function deploy(name, args = []) {
  const Implementation = await ethers.getContractFactory(name);
  const contract = await Implementation.deploy(...args);
  return contract.deployed();
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

module.exports = {
  deployTestContractSetup,
  deploy,
  getTokenVault,
};
