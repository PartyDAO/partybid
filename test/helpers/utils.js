const BigNumber = require('bignumber.js');

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
    balances[name]['eth'] = new BigNumber(parseFloat(weiToEth(await provider.getBalance(address))));
    let tokenBalance = 0;
    if(token && token.address != ethers.constants.AddressZero) {
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

async function emergencyCall(partyBidContract, signer, contractAddress, calldata) {
  const data = encodeData(partyBidContract, 'emergencyCall', [contractAddress, calldata]);

  return signer.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function emergencyForceLost(partyBidContract, signer) {
  const data = encodeData(partyBidContract, 'emergencyForceLost',);

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

module.exports = {
  eth,
  weiToEth,
  encodeData,
  getBalances,
  getTotalContributed,
  approve,
  contribute,
  emergencyWithdrawEth,
  emergencyCall,
  emergencyForceLost,
  initExpectedTotalContributed
};
