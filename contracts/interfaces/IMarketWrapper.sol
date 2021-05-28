// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/**
 * @title IMarketWrapper
 * @author Anna Carroll
 * @notice IMarketWrapper provides a common interface for
 * interacting with NFT auction markets.
 * Contracts can abstract their interactions with
 * different NFT markets using IMarketWrapper.
 * NFT markets can become compatible with any contract
 * using IMarketWrapper by deploying a MarketWrapper contract
 * that implements this interface using the logic of their Market.
 */
interface IMarketWrapper {
    /**
     * @notice Get the address of the Market being wrapped
     * @return address of the underlying market
     */
    function getMarketAddress() external view returns (address);

    /**
     * @notice Determine whether there is an existing auction
     * for this token on the underlying market
     * @return TRUE if the auction exists
     */
    function auctionExists(address nftContract, uint256 tokenId)
        external
        view
        returns (bool);

    /**
     * @notice Get the auctionId for this token on the underlying market
     * @return auctionId
     */
    function getAuctionId(address nftContract, uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @notice Calculate the minimum next bid for this auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId) external view returns (uint256);

    /**
     * @notice Encode the data to call the bidding function
     * @return bid calldata
     */
    function getBidData(uint256 auctionId, uint256 bidAmount)
        external
        pure
        returns (bytes memory);

    /**
     * @notice Determine whether the auction has been finalized
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId) external view returns (bool);

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external;
}
