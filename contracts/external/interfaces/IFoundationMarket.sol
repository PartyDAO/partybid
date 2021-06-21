// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IFoundationMarket {
    struct ReserveAuction {
        address nftContract;
        uint256 tokenId;
        address payable seller;
        uint256 duration;
        uint256 extensionDuration;
        uint256 endTime;
        address payable bidder;
        uint256 amount;
    }

    function getMinBidAmount(uint256 auctionId) external view returns (uint256);

    function placeBid(uint256 auctionId) external payable;

    function getReserveAuction(uint256 auctionId)
        external
        view
        returns (ReserveAuction memory);

    function getReserveAuctionIdFor(address nftContract, uint256 tokenId)
        external
        view
        returns (uint256);

    function finalizeReserveAuction(uint256 auctionId) external;
}
