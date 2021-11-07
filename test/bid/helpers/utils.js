const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('../../helpers/constants');

async function bidThroughParty(partyBidContract, signer) {
  const data = encodeData(partyBidContract, 'bid');

  return signer.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function createReserveAuction(
  artist,
  marketContract,
  nftContractAddress,
  tokenId,
  reservePrice,
) {
  const data = encodeData(marketContract, 'createReserveAuction', [
    nftContractAddress,
    tokenId,
    reservePrice,
  ]);

  return artist.sendTransaction({
    to: marketContract.address,
    data,
  });
}

async function createZoraAuction(
  artist,
  marketContract,
  tokenId,
  tokenContractAddress,
  reservePrice,
  duration = FOURTY_EIGHT_HOURS_IN_SECONDS,
  curatorFeePercentage = 0,
) {
  const data = encodeData(marketContract, 'createAuction', [
    tokenId,
    tokenContractAddress,
    duration,
    reservePrice,
    artist.address,
    curatorFeePercentage,
    ethers.constants.AddressZero,
  ]);

  return artist.sendTransaction({
    to: marketContract.address,
    data,
  });
}

module.exports = {
  bidThroughParty,
  createReserveAuction,
  createZoraAuction
};
