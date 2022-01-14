const BigNumber = require('bignumber.js');
const { FOURTY_EIGHT_HOURS_IN_SECONDS } = require('./constants');

function eth(num) {
  return ethers.utils.parseEther(num.toString());
}
function weiToEth(num) {
  return parseFloat(ethers.utils.formatEther(num.toString()));
}

function encodeData(contract, functionName, args) {
  const func = contract.interface.getFunction(functionName);
  return contract.interface.encodeFunctionData(func, args);
}

async function getBalances(provider, token, accounts) {
  const balances = {};
  for (let account of accounts) {
    const { name, address } = account;
    balances[name] = {};
    balances[name]['eth'] = new BigNumber(
      parseFloat(weiToEth(await provider.getBalance(address))),
    );
    let tokenBalance = 0;
    if (token && token.address != ethers.constants.AddressZero) {
      tokenBalance = weiToEth(await token.balanceOf(address));
    }
    balances[name]['tokens'] = new BigNumber(parseFloat(tokenBalance));
  }
  return balances;
}

function getTotalContributed(contributions) {
  let totalContributed = 0;
  contributions.map((contribution) => {
    totalContributed += contribution.amount;
  });
  return totalContributed;
}

async function approve(signer, tokenContract, to, tokenId) {
  const data = encodeData(tokenContract, 'approve', [to, tokenId]);

  return signer.sendTransaction({
    to: tokenContract.address,
    data,
  });
}

async function contribute(partyBidContract, contributorSigner, value) {
  const data = encodeData(partyBidContract, 'contribute');

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
    data,
    value,
  });
}

async function emergencyWithdrawEth(partyBidContract, signer, value) {
  const data = encodeData(partyBidContract, 'emergencyWithdrawEth', [value]);

  return signer.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function emergencyCall(
  partyBidContract,
  signer,
  contractAddress,
  calldata,
) {
  const data = encodeData(partyBidContract, 'emergencyCall', [
    contractAddress,
    calldata,
  ]);

  return signer.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function emergencyForceLost(partyBidContract, signer) {
  const data = encodeData(partyBidContract, 'emergencyForceLost');

  return signer.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function expire(partyBidContract, signer) {
  const data = encodeData(partyBidContract, 'expire');

  return signer.sendTransaction({
    to: partyBidContract.address,
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
  eth,
  weiToEth,
  encodeData,
  expire,
  getBalances,
  getTotalContributed,
  approve,
  contribute,
  emergencyWithdrawEth,
  emergencyCall,
  emergencyForceLost,
  initExpectedTotalContributed,
  bidThroughParty,
  createReserveAuction,
  createZoraAuction,
};
