// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IPartyBidFactory {
    // ============ Public Immutable Variables ============

    // PartyBid logic contract address
    function logic() external view returns(address);

    // PartyDAO multisig contract address
    function partyDAOMultisig() external view returns(address);

    // token vault factory contract address
    function tokenVaultFactory() external view returns(address);

    // weth contract address
    function weth() external view returns(address);

    // ============ Public Storage Variables ============

    // PartyBid proxy => block number deployed at
    function deployedAt(address) external view returns(uint256);

    //======== Deploy function =========

    function startParty(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        string memory _name,
        string memory _symbol
    ) external returns (address partyBidProxy);
}
