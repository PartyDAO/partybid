const { ethers } = require("hardhat");

function getDeployer(RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY) {
  const provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
  const deployer = new ethers.Wallet(`0x${DEPLOYER_PRIVATE_KEY}`, provider);
  return deployer;
}

async function deploy(wallet, name, args = []) {
  const Implementation = await ethers.getContractFactory(name, wallet);
  const contract = await Implementation.deploy(...args);
  return contract.deployed();
}

module.exports = {
  getDeployer,
  deploy,
};
