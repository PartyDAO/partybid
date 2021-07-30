const { FOURTY_EIGHT_HOURS_IN_SECONDS, MARKET_NAMES } = require('./constants');

function eth(num) {
  return ethers.utils.parseEther(num.toString());
}
function weiToEth(num) {
  return ethers.utils.formatEther(num.toString());
}

function encodeData(contract, functionName, args) {
  const func = contract.interface.getFunction(functionName);
  return contract.interface.encodeFunctionData(func, args);
}

async function sendFromSigner(signer, contract, functionName, args, value = null) {
  const data = encodeData(contract, functionName, args);
  return signer.sendTransaction({
    to: contract.address,
    data,
    value
  });
}

async function claim(signer, partyBidContract, contributor) {
  return sendFromSigner(signer, partyBidContract, "claim", [contributor]);
}

async function approve(signer, tokenContract, to, tokenId) {
  return sendFromSigner(signer, tokenContract, "approve", [to, tokenId]);
}

async function placeBid(signer, marketContract, auctionId, value, marketName) {
  if (marketName == MARKET_NAMES.ZORA) {
    return sendFromSigner(signer, marketContract, "createBid", [auctionId, value], value);
  } else {
    return sendFromSigner(signer, marketContract, "placeBid", [auctionId], value);
  }
}

async function contribute(partyBidContract, contributorSigner, value) {
  return sendFromSigner(contributorSigner, partyBidContract, "contribute", [], value);
}

async function redeem(partyBidContract, contributorSigner, amount) {
  return sendFromSigner(contributorSigner, partyBidContract, "redeem", [amount]);
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
  return sendFromSigner(artist, marketContract, "createAuction", [
    tokenId,
    tokenContractAddress,
    duration,
    reservePrice,
    artist.address,
    curatorFeePercentage,
    ethers.constants.AddressZero,
  ]);
}

async function createReserveAuction(
  artist,
  marketContract,
  nftContractAddress,
  tokenId,
  reservePrice,
) {
  return sendFromSigner(artist, marketContract, "createReserveAuction", [nftContractAddress, tokenId, reservePrice]);
}

async function getBalances(provider, token, accounts) {
  const balances = {};
  for (let account of accounts) {
    const { name, address } = account;
    balances[name] = {};
    balances[name]['eth'] = parseFloat(
        weiToEth(await provider.getBalance(address)),
    );
    let tokenBalance = 0;
    if(token.address != ethers.constants.AddressZero) {
      tokenBalance = parseFloat(
          weiToEth(await token.balanceOf(address)),
      );
    }
    balances[name]['tokens'] = tokenBalance;
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
  initExpectedTotalContributed,
  approve,
  contribute,
  claim,
  redeem,
  placeBid,
  createReserveAuction,
  createZoraAuction,
};
