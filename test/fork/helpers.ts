// @ts-ignore
import hre from "hardhat";
const fs = require("fs");

// https://cmichel.io/replaying-ethereum-hacks-introduction/?no-cache=1
export async function forkFrom(blockNumber: number) {
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

export function getConfig() {
    return JSON.parse(fs.readFileSync(`./test/fork/config.json`));
};

export function getDeployedAddresses() {
    const CHAIN_NAME = "mainnet";
    const directory = "./deploy/deployed-contracts";
    const filename = `${directory}/${CHAIN_NAME}.json`;
    let contractAddresses;
    try {
        contractAddresses = JSON.parse(fs.readFileSync(filename));
    } catch (e) {
        console.error(e);
        contractAddresses = {
            chain: CHAIN_NAME,
        };
    }
    return {directory, filename, contractAddresses};
}
