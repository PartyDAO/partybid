const { encodeData } = require('./utils');
const { MARKET_NAMES } = require('./constants');

async function placeBid(signer, marketContract, auctionId, value, marketName) {
  let data;
  if (marketName == MARKET_NAMES.ZORA) {
    data = encodeData(marketContract, 'createBid', [auctionId, value]);
  } else if (marketName == MARKET_NAMES.NOUNS) {
    data = encodeData(marketContract, 'createBid', [auctionId]);
  } else if (marketName == MARKET_NAMES.FOUNDATION) {
    data = encodeData(marketContract, 'placeBid', [auctionId]);
  } else if (marketName == MARKET_NAMES.KOANS) {
    data = encodeData(marketContract, 'createBid', [auctionId]);
  } else {
    throw new Error('Unsupported Market');
  }

  return signer.sendTransaction({
    to: marketContract.address,
    data,
    value,
  });
}

async function externalFinalize(signer, marketContract, auctionId, marketName) {
  let data;
  if (marketName == MARKET_NAMES.ZORA) {
    data = encodeData(marketContract, 'endAuction', [auctionId]);
  } else if (marketName == MARKET_NAMES.NOUNS) {
    data = encodeData(marketContract, 'settleCurrentAndCreateNewAuction', []);
  } else if (marketName == MARKET_NAMES.FOUNDATION) {
    data = encodeData(marketContract, 'finalizeReserveAuction', [auctionId]);
  } else if (marketName == MARKET_NAMES.KOANS) {
    data = encodeData(marketContract, 'settleCurrentAndCreateNewAuction', []);
  } else {
    throw new Error('Unsupported Market');
  }

  return signer.sendTransaction({
    to: marketContract.address,
    data,
  });
}

async function cancelAuction(
  artistSigner,
  marketContract,
  auctionId,
  marketName,
) {
  let data;
  if (marketName == MARKET_NAMES.ZORA) {
    data = encodeData(marketContract, 'cancelAuction', [auctionId]);
  } else if (marketName == MARKET_NAMES.FOUNDATION) {
    data = encodeData(marketContract, 'cancelReserveAuction', [auctionId]);
  } else {
    throw new Error('Unsupported Market');
  }

  return artistSigner.sendTransaction({
    to: marketContract.address,
    data,
  });
}

module.exports = {
  placeBid,
  externalFinalize,
  cancelAuction,
};
