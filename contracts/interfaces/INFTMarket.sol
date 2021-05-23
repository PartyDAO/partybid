// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface INFTMarket {
    function getReserveAuctionIdFor(address nftContract, uint256 tokenId)
        external
        view
        returns (uint256);
}
