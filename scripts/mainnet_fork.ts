import hre, { ethers } from "hardhat";
import "@nomiclabs/hardhat-ethers";
import { erc20abi, erc721abi, partyBidAbi } from "./helpers/abis";

// https://cmichel.io/replaying-ethereum-hacks-introduction/?no-cache=1
export const forkFrom = async (blockNumber: number) => {
  if (!hre.config.networks.forking) {
    throw new Error(
      `Forking misconfigured for "hardhat" network in hardhat.config.ts`
    );
  }

  await hre.network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: (hre.config.networks.forking as any).url,
          blockNumber: blockNumber,
        },
      },
    ],
  });
};

const BLOCK_NUMBER = 12986459;
const PARTY_BID_FACTORY = "0xdb355da657A3795bD6Faa9b63915cEDbE4fAdb00";
const MARKET_WRAPPER = "0x11c07cE1315a3b92C9755F90cDF40B04b88c5731";
const ADDRESS_TO_IMPERSONATE = "0xab5801a7d398351b8be11c439e05c5b3259aec9b"; // vitalik

const NFT_CONTRACT = "0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6";
const TOKEN_ID = 3269;
const AUCTION_ID = 769;
const TOKEN_NAME = "SIRSU";
const TOKEN_SYMBOL = "SIRSU";

const go = async () => {
  console.log(`forking from ${BLOCK_NUMBER}`);
  await forkFrom(BLOCK_NUMBER);
  console.log(`forked from ${BLOCK_NUMBER}`);

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

go().then(() => {
  process.exit();
});
