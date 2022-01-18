const fs = require("fs");
const dotenv = require("dotenv");

function loadEnv() {
    dotenv.config();
    const {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY} = process.env;
    if (!(CHAIN_NAME && RPC_ENDPOINT && DEPLOYER_PRIVATE_KEY)) {
        throw new Error("Must populate all values in .env - see .env.example for full list");
    }
    return {CHAIN_NAME, RPC_ENDPOINT, DEPLOYER_PRIVATE_KEY};
}

function loadConfig(CHAIN_NAME) {
    return JSON.parse(fs.readFileSync(`./deploy/configs/${CHAIN_NAME}.json`));
}

function getDeployedAddresses(type, CHAIN_NAME) {
    const directory = `./deploy/${type}/deployed-contracts`;
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

function writeDeployedAddresses(directory, filename, addresses) {
    fs.mkdirSync(directory, {recursive: true});
    fs.writeFileSync(
        filename,
        JSON.stringify(addresses, null, 2),
    );
}

/*
 * Given one contract verification input,
 * attempt to verify the contracts' source code on Etherscan
 * */
async function verifyContract(address, constructorArguments) {
    const {CHAIN_NAME} = loadEnv();
    if (!(CHAIN_NAME) ) {
        throw new Error("Must add chain name to .env");
    } else if(hre.network.name != CHAIN_NAME) {
        throw new Error(`CHAIN_NAME in .env file is "${CHAIN_NAME}" but hardhat --network in package.json is "${hre.network.name}; change them to match"`)
    }
    try {
        await hre.run('verify:verify', {
            network: CHAIN_NAME,
            address,
            constructorArguments,
        });
    } catch (e) {
        console.error(e);
    }
    console.log('\n\n'); // add space after each attempt
}

module.exports = {
    loadEnv,
    loadConfig,
    verifyContract,
    getDeployedAddresses,
    writeDeployedAddresses
};
