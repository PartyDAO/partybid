// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IMarket {
    function getReserveAuctionIdFor(address nftContract, uint256 tokenId)
        external
        view
        returns (uint256);

    function getMinBidAmount(uint256 auctionId) external view returns (uint256);

    function placeBid(uint256 auctionId) external payable;
}
