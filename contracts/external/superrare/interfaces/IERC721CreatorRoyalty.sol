// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "./IERC721TokenCreator.sol";

/**
 * @title IERC721CreatorRoyalty Token level royalty interface.
 */
interface IERC721CreatorRoyalty is IERC721TokenCreator {
    /**
     * @dev Get the royalty fee percentage for a specific ERC721 contract.
     * @param _contractAddress address ERC721Contract address.
     * @param _tokenId uint256 token ID.
     * @return uint8 wei royalty fee.
     */
    function getERC721TokenRoyaltyPercentage(
        address _contractAddress,
        uint256 _tokenId
    ) external view returns (uint8);

    /**
     * @dev Utililty function to calculate the royalty fee for a token.
     * @param _contractAddress address ERC721Contract address.
     * @param _tokenId uint256 token ID.
     * @param _amount uint256 wei amount.
     * @return uint256 wei fee.
     */
    function calculateRoyaltyFee(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external view returns (uint256);

    /**
     * @dev Utililty function to set the royalty percentage for a specific ERC721 contract.
     * @param _contractAddress address ERC721Contract address.
     * @param _percentage percentage for royalty
     */
    function setPercentageForSetERC721ContractRoyalty(
        address _contractAddress,
        uint8 _percentage
    ) external;
}
