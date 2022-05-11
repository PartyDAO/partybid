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
  } else if (marketName == MARKET_NAMES.FRACTIONAL) {
    const fractionalTokenVaultAddress = await marketContract.vaults(auctionId);
    const logic = await ethers.getContractFactory('TokenVault');
    const fractionalTokenVault = new ethers.Contract(fractionalTokenVaultAddress, logic.interface, signer);
    const tokenState = await fractionalTokenVault.auctionState();
    let funcName;
    if (tokenState == 0) {
      funcName = 'start';
    } else if (tokenState == 1) {
      funcName = 'bid';
    } else {
      throw new Error('Fractional Token is either ended or redeemed.')
    }
    data = encodeData(fractionalTokenVault, funcName, []);

    return signer.sendTransaction({
      to: fractionalTokenVault.address,
      data,
      value,
      gasLimit: 900000 /* hardhat test cannot estimate gas */,
    });
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
  } else if (marketName == MARKET_NAMES.FRACTIONAL) {
    const fractionalTokenVaultAddress = await marketContract.vaults(auctionId);
    const logic = await ethers.getContractFactory('TokenVault');
    const fractionalTokenVault = new ethers.Contract(fractionalTokenVaultAddress, logic.interface, signer);
    data = encodeData(fractionalTokenVault, 'end', []);

    return signer.sendTransaction({
      to: fractionalTokenVault.address,
      data,
    });
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
