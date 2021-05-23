async function deploy(name, arguments) {
    const Implementation = await ethers.getContractFactory(name);
    const contract = await Implementation.deploy(...arguments);
    return contract.deployed();
}

async function deployERC721AndMint(artistAddress, tokenID) {
    const nftContract = await deploy('TestERC721');
    await nftContract.mint(artistAddress, tokenID);
}

async function deployFoundationMarket() {
    const treasury = await deploy('FakeFoundationTreasury');
    const foundationMarket = await deploy('FNDNFTMarket');
    await foundationMarket.initialize(treasury.address);
    return foundationMarket;
}
