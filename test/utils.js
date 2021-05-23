const { NFT_TYPE_ENUM, NFT_TYPES } = require('./constants');

function eth(num) {
  return ethers.utils.parseEther(num.toString());
}

function encodeData(contract, functionName, arguments) {
  const func = contract.interface.getFunction(functionName);
  return contract.interface.encodeFunctionData(func, arguments);
}

async function approve(signer, tokenContract, to, tokenId) {
  const data = encodeData(tokenContract, 'approve', [to, tokenId]);

  return signer.sendTransaction({
    to: tokenContract.address,
    data,
  });
}

async function contribute(partyBidContract, contributorSigner, value) {
  const data = encodeData(partyBidContract, 'contribute', [
    contributorSigner.address,
    value,
  ]);

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
    data,
    value,
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

function initExpectedTotalContributed(signers) {
  const expectedTotalContributed = {};
  signers.map((signer) => {
    expectedTotalContributed[signer.address] = 0;
  });
  return expectedTotalContributed;
}

module.exports = {
  eth,
  encodeData,
  approve,
  contribute,
  createReserveAuction,
  initExpectedTotalContributed,
};
