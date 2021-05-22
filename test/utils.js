const { NFT_TYPE_ENUM, NFT_TYPES } = require('./constants');

function eth(num) {
  return ethers.utils.parseEther(num.toString());
}

async function deployPartyBid(
  nftType = NFT_TYPES.ZORA,
  tokenId = 100,
  quorumPercent = 50,
  tokenName = 'Party',
  tokenSymbol = 'PARTY',
) {
  const PartyBid = await ethers.getContractFactory('PartyBid');
  const partyBid = await PartyBid.deploy(
    NFT_TYPE_ENUM[nftType],
    tokenId,
    quorumPercent,
    tokenName,
    tokenSymbol,
  );
  return partyBid.deployed();
}

async function contribute(partyBidContract, contributorSigner, value) {
  const contributeFunction = partyBidContract.interface.getFunction(
    'contribute',
  );
  const contributeData = partyBidContract.interface.encodeFunctionData(
    contributeFunction,
    [contributorSigner.address, value],
  );

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
    data: contributeData,
    value,
  });
}

module.exports = {
  eth,
  deployPartyBid,
  contribute,
};
