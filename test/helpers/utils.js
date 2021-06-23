const { expect } = require('chai');
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

async function getBalances(provider, token, accounts) {
  const balances = {};
  for (let account of accounts) {
    const { name, address } = account;
    balances[name] = {};
    balances[name]['eth'] = parseFloat(
      weiToEth(await provider.getBalance(address)),
    );
    balances[name]['tokens'] = parseFloat(
      weiToEth(await token.balanceOf(address)),
    );
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

async function placeBid(signer, marketContract, auctionId, value, marketName) {
  let data;
  if (marketName == MARKET_NAMES.ZORA) {
    data = encodeData(marketContract, 'createBid', [auctionId, value]);
  } else {
    data = encodeData(marketContract, 'placeBid', [auctionId]);
  }

  return signer.sendTransaction({
    to: marketContract.address,
    data,
    value,
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

async function redeem(partyBidContract, contributorSigner, amount) {
  const data = encodeData(partyBidContract, 'redeem', [amount]);

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function supportReseller(
  partyBidContract,
  contributorSigner,
  reseller,
  resellerCalldata,
) {
  const data = encodeData(partyBidContract, 'supportReseller', [
    reseller,
    resellerCalldata,
  ]);

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
    data,
  });
}

async function transfer(
  partyBidContract,
  contributorSigner,
  recipient,
  amount,
) {
  const data = encodeData(partyBidContract, 'transfer', [recipient, amount]);

  return contributorSigner.sendTransaction({
    to: partyBidContract.address,
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

// Validate state variables based on ETH amount added to contract
async function expectRedeemable(
  provider,
  partyBid,
  ethAmountAdded,
  ethAmountRedeemed,
) {
  const redeemableEth = ethAmountAdded - ethAmountRedeemed;

  // eth balance is equal to redeemableEth + excessContributions
  const excessContributions = await partyBid.excessContributions();
  const expectedBalance =
    redeemableEth + parseFloat(weiToEth(excessContributions));
  const ethBalance = await provider.getBalance(partyBid.address);
  await expect(ethBalance).to.equal(eth(expectedBalance));

  // redeemableEthBalance is equal to ethAmountAdded
  const redeemableEthBalance = await partyBid.redeemableEthBalance();
  await expect(redeemableEthBalance).to.equal(eth(redeemableEth));

  // redeemAmount(tokenAmount) is expected portion
  const tokenAmount = 100;
  const totalSupply = await partyBid.totalSupply();
  const expectedRedeemAmount =
    redeemableEth * (tokenAmount / parseFloat(weiToEth(totalSupply)));
  const redeemAmount = await partyBid.redeemAmount(eth(tokenAmount));
  await expect(redeemAmount).to.equal(eth(expectedRedeemAmount));
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
  placeBid,
  redeem,
  supportReseller,
  transfer,
  createReserveAuction,
  createZoraAuction,
  expectRedeemable,
};
