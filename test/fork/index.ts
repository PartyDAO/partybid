// @ts-ignore
import hre, {ethers} from "hardhat";
import "@nomiclabs/hardhat-ethers";
import {erc20abi, erc721abi, partyBidAbi} from "./abis";
import {forkFrom, getConfig, getDeployedAddresses} from "./helpers";

// load config
const config = getConfig();
const {ADDRESS_TO_IMPERSONATE, MARKET_NAME} = config;
const market = config[MARKET_NAME];
const {BLOCK_NUMBER, NFT_CONTRACT, TOKEN_ID, AUCTION_ID, TOKEN_NAME, TOKEN_SYMBOL} = market;

// load mainnet contract addresses
const {contractAddresses} = getDeployedAddresses();
const PARTY_BID_FACTORY = contractAddresses["partyBidFactory"];
const MARKET_WRAPPER = contractAddresses["marketWrappers"][MARKET_NAME];

forkTest().then(() => {
  console.log("DONE!");
  process.exit();
});

async function forkTest() {
  console.log(`Fork testing ${MARKET_NAME}`);

  console.log(`forking from block ${BLOCK_NUMBER}`);
  await forkFrom(BLOCK_NUMBER);
  console.log(`forked from block ${BLOCK_NUMBER}`);

  console.log(`impersonate user`);

  // impersonate user
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [ADDRESS_TO_IMPERSONATE],
  });
  const vitalik = ethers.provider.getSigner(ADDRESS_TO_IMPERSONATE);

  console.log(`get contract`);

  // get contract
  const partyBidFactory = await ethers.getContractAt(
    "PartyBidFactory",
    PARTY_BID_FACTORY
  );

  console.log(`get ERC-721`);
  const erc721Contract = new ethers.Contract(NFT_CONTRACT, erc721abi, vitalik);
  console.log("original owner of NFT:", await erc721Contract.ownerOf(TOKEN_ID));

  // start party
  const startPartyTxnData = partyBidFactory.interface.encodeFunctionData(
    `startParty`,
    [
      MARKET_WRAPPER,
      NFT_CONTRACT,
      TOKEN_ID,
      AUCTION_ID,
      TOKEN_NAME,
      TOKEN_SYMBOL,
    ]
  );

  const tx = await vitalik.sendTransaction({
    to: partyBidFactory.address,
    data: startPartyTxnData,
  });

  console.log(JSON.stringify(tx));

  const provider = vitalik.provider;
  const startTxnReceipt = await provider.getTransactionReceipt(tx.hash);
  const parsedStartTxnLogs = startTxnReceipt.logs.map((l) =>
    partyBidFactory.interface.parseLog(l)
  );
  const foundDeployedLog = parsedStartTxnLogs.find(
    (l) => l.name === "PartyBidDeployed"
  );
  if (!foundDeployedLog) {
    throw new Error(`cant find deploy log`);
  }
  const deployedPartyBidAddress = foundDeployedLog.args[0];

  // console.log(JSON.stringify(foundDeployedLog));
  // console.log(deployedPartyBidAddress);

  // grab the party
  const party = new ethers.Contract(
    deployedPartyBidAddress,
    partyBidAbi,
    vitalik
  );
  const contribAmount = 500 * 10 ** 18;

  const vitalikContrib = await party.contribute({
    value: contribAmount.toString(),
  });
  console.log("contribution:", vitalikContrib);
  await vitalikContrib.wait();
  console.log("contribution successful");

  const totalContribed = await party.totalContributedToParty();
  console.log("total contributed", totalContribed.toString());

  const bid = await party.bid();
  await bid.wait();

  console.log("bid created successfully", bid);

  // increase time and finalize
  const ONE_HOUR = 60 * 60;
  const secondsIncrease = ONE_HOUR * 48;
  await provider.send("evm_increaseTime", [secondsIncrease]);
  await provider.send("evm_mine", []);

  await party.finalize();

  const status = await party.partyStatus();
  console.log("status", JSON.stringify(status));

  const fractionalTokenAddress = await party.tokenVault();
  const fractionalToken = new ethers.Contract(
    fractionalTokenAddress,
    erc20abi,
    vitalik
  );

  const ogVitalikBalance = await fractionalToken.balanceOf(
    ADDRESS_TO_IMPERSONATE
  );
  console.log("initial balance", ogVitalikBalance.toString());

  await party.claim(ADDRESS_TO_IMPERSONATE);

  const newVitalikBalance = await fractionalToken.balanceOf(
    ADDRESS_TO_IMPERSONATE
  );
  console.log("new balance", newVitalikBalance.toString());

  console.log(
    "new owner of NFT:",
    await erc721Contract.ownerOf(TOKEN_ID),
    "fractional token",
    fractionalTokenAddress
  );
};

