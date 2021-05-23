const { eth, approve, createReserveAuction } = require('./utils');

async function deploy(name, arguments = []) {
  const Implementation = await ethers.getContractFactory(name);
  const contract = await Implementation.deploy(...arguments);
  return contract.deployed();
}

async function deployPartyBid(
  market,
  nftContract,
  tokenId = 100,
  quorumPercent = 50,
  tokenName = 'Party',
  tokenSymbol = 'PARTY',
) {
  return deploy('PartyBid', [
    market,
    nftContract,
    tokenId,
    quorumPercent,
    tokenName,
    tokenSymbol,
  ]);
}

async function deployFoundationMarket() {
  const treasury = await deploy('FakeFoundationTreasury');
  const foundationMarket = await deploy('FNDNFTMarket');
  await foundationMarket.initialize(treasury.address);
  return foundationMarket;
}

async function deployTestSetupFoundation(
  artistSigner,
  tokenId = 100,
  reservePrice = 1,
) {
  // Deploy NFT Contract & Mint Token
  const nftContract = await deploy('TestERC721');
  await nftContract.mint(artistSigner.address, tokenId);

  // Deploy Foundation Market
  const foundationMarket = await deployFoundationMarket();

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

  // Deploy PartyBid
  const partyBid = await deployPartyBid(
    foundationMarket.address,
    nftContract.address,
    tokenId,
  );

  return {
    nftContract,
    market: foundationMarket,
    partyBid,
  };
}

module.exports = {
  deployPartyBid,
  deployTestSetupFoundation,
  deployFoundationMarket,
  deploy,
};
