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

async function deployTestContractSetup(
  artistSigner,
  tokenId = 100,
  reservePrice = 1,
) {
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

  // Deploy Reseller Whitelist & Approve PartyDAO multisig for all
  const whitelist = await deploy('ResellerWhitelist');
  await whitelist.updateWhitelistForAll(partyDAOMultisig.address, true);

  // Deploy PartyBid
  const partyBid = await deployPartyBid(
    partyDAOMultisig.address,
    whitelist.address,
    marketWrapper.address,
    nftContract.address,
    tokenId,
    auctionId,
  );

  return {
    nftContract,
    market: foundationMarket,
    partyBid,
    partyDAOMultisig,
    whitelist,
  };
}

module.exports = {
  deployPartyBid,
  deployTestContractSetup,
  deployFoundationMarket,
  deploy,
};
