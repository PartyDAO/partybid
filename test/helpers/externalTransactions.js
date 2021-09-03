const { encodeData } = require('./utils');
const { MARKET_NAMES } = require('./constants');
// const { ethers } = require('ethers');

async function placeBid(signer, marketContract, auctionId, value, marketName) {
    let data;
    let targetAddress = marketContract.address;
    if (marketName == MARKET_NAMES.ZORA) {
        data = encodeData(marketContract, 'createBid', [auctionId, value]);
    } else if (marketName == MARKET_NAMES.NOUNS) {
        data = encodeData(marketContract, 'createBid', [auctionId]);
    } else if (marketName == MARKET_NAMES.FOUNDATION) {
        data = encodeData(marketContract, 'placeBid', [auctionId]);
    } else if (marketName == MARKET_NAMES.FRACTIONAL) {
        let vaultAddress = await marketContract.functions.vaults(auctionId);
        let vaultContract = await ethers.getContractFactory("TokenVault");
        vaultContract = await vaultContract.attach(vaultAddress); // This is not a token vault? Func selector not recognized
        // vaultContract = await vaultContract.attach("0x5cc657F6c8A9314c9aD2Ad51daa44eC929EF5b9a"); // random one
        console.log(`vaultAddress: ${vaultAddress}, vaultContract.address: ${vaultContract.address}`);
        let token = await vaultContract.functions.token();
        console.log(`token: ${token}`);
        // console.log(`vault interface: ${vaultContract.interface.format(ethers.utils.FormatTypes.full)}`);
        // console.log(`factory interface: ${marketContract.interface.format(ethers.utils.FormatTypes.full)}`);
        data = encodeData(vaultContract, 'bid', [])
        targetAddress = vaultAddress;
        console.log('end of encoding');
    } else {
        throw new Error("Unsupported Market");
    }

    console.log(`Sending tx from ${signer.address} to ${targetAddress}`);
    let res = await signer.sendTransaction({
        to: targetAddress,
        data: data,
        value: value,
    });
    console.log(`Success, ${res}`);
    return res;
}

async function externalFinalize(signer, marketContract, auctionId, marketName) {
    let data;
    if (marketName == MARKET_NAMES.ZORA) {
        data = encodeData(marketContract, 'endAuction', [auctionId]);
    } else if (marketName == MARKET_NAMES.NOUNS) {
        data = encodeData(marketContract, 'settleCurrentAndCreateNewAuction', []);
    } else if (marketName == MARKET_NAMES.FOUNDATION) {
        data = encodeData(marketContract, 'finalizeReserveAuction', [auctionId]);
    } else if (marketName == MARKET_NAME.FRACTIONAL) {
        data = encodeData(marketContract, 'TODO', []);
    } else {
        throw new Error("Unsupported Market");
    }

    return signer.sendTransaction({
        to: marketContract.address,
        data,
    });
}

async function cancelAuction(artistSigner, marketContract, auctionId, marketName) {
    // Neither Nouns nor Fractional let you cancel an auction
    let data;
    if (marketName == MARKET_NAMES.ZORA) {
        data = encodeData(marketContract, 'cancelAuction', [auctionId]);
    } else if(marketName == MARKET_NAMES.FOUNDATION) {
        data = encodeData(marketContract, 'cancelReserveAuction', [auctionId]);
    } else {
        throw new Error("Unsupported Market");
    }

    return artistSigner.sendTransaction({
        to: marketContract.address,
        data,
    });
}

module.exports = {
    placeBid,
    externalFinalize,
    cancelAuction
};
