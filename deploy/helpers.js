const fs = require("fs");

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

module.exports = {
    getDeployedAddresses,
    writeDeployedAddresses
};
