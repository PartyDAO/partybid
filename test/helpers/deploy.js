const { eth, approve, createReserveAuction } = require('./utils');

async function deploy(name, arguments = []) {
  const Implementation = await ethers.getContractFactory(name);
  const contract = await Implementation.deploy(...arguments);
  return contract.deployed();
}

async function deployPartyBid(
  partyDAOMultisig,
  market,
  nftContract,
  tokenId = 100,
  quorumPercent = 50,
  tokenName = 'Party',
  tokenSymbol = 'PARTY',
) {
  return deploy('PartyBid', [
    partyDAOMultisig,
    market,
    nftContract,
    tokenId,
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

  // Deploy PartyDAO multisig
  const partyDAOMultisig = await deploy('PayableContract');

  // Deploy PartyBid
  const partyBid = await deployPartyBid(
    partyDAOMultisig.address,
    foundationMarket.address,
    nftContract.address,
    tokenId,
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
  deployTestContractSetup,
  deployFoundationMarket,
  deploy,
};
