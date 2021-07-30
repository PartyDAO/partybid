// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

/**
 * @notice An abstraction layer for auctions.
 * @dev This contract can be expanded with reusable calls and data as more auction types are added.
 */
abstract contract NFTMarketAuction {
    /**
     * @dev A global id for auctions of any type.
     */
    uint256 private nextAuctionId;

    function _initializeNFTMarketAuction() internal {
        nextAuctionId = 1;
    }

    function _getNextAndIncrementAuctionId() internal returns (uint256) {
        return nextAuctionId++;
    }

    uint256[1000] private ______gap;
}