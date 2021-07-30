// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable2/token/ERC721/IERC721Upgradeable.sol";

/**
 * @notice A place for common modifiers and functions used by various NFTMarket mixins, if any.
 * @dev This also leaves a gap which can be used to add a new mixin to the top of the inheritance tree.
 */
abstract contract NFTMarketCore {
    /**
     * @dev If the auction did not have an escrowed seller to return, this falls back to return the current owner.
     * This allows functions to calculate the correct fees before the NFT has been listed in auction.
     */
    function _getSellerFor(address nftContract, uint256 tokenId) internal view virtual returns (address payable) {
        return payable(IERC721Upgradeable(nftContract).ownerOf(tokenId));
    }

    // 50 slots were consumed by adding ReentrancyGuardUpgradeable
    uint256[950] private ______gap;
}