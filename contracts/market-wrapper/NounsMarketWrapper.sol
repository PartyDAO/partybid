// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports ============
import {INounsAuctionHouse} from "../external/interfaces/INounsAuctionHouse.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title NounsMarketWrapper
 * @author Anna Carroll + Nounders
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Nouns' Auction Houses
 */
contract NounsMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============

    INounsAuctionHouse public immutable market;

    // ======== Constructor =========

    constructor(address _nounsAuctionHouse) {
        market = INounsAuctionHouse(_nounsAuctionHouse);
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether there is an existing, active auction
     * for this token. In the Nouns auction house, the current auction
     * id is the token id, which increments sequentially, forever. The
     * auction is considered active while the current block timestamp
     * is less than the auction's end time.
     * @return TRUE if the auction exists
     */
    function auctionExists(uint256 auctionId) public view returns (bool) {
        (uint256 currentAuctionId, , , uint256 endTime, , ) = market.auction();
        return auctionId == currentAuctionId && block.timestamp < endTime;
    }

    /**
     * @notice Determine whether the given auctionId and tokenId is active.
     * We ignore nftContract since it is static for all nouns auctions.
     * @return TRUE if the auctionId and tokenId matches the active auction
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address, /* nftContract */
        uint256 tokenId
    ) public view override returns (bool) {
        return auctionId == tokenId && auctionExists(auctionId);
    }

    /**
     * @notice Calculate the minimum next bid for the active auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId)
        external
        view
        override
        returns (uint256)
    {
        require(
            auctionExists(auctionId),
            "NounsMarketWrapper::getMinimumBid: Auction not active"
        );

        (, uint256 amount, , , address payable bidder, ) = market.auction();
        if (bidder == address(0)) {
            // if there are NO bids, the minimum bid is the reserve price
            return market.reservePrice();
        }
        // if there ARE bids, the minimum bid is the current bid plus the increment buffer
        uint8 minBidIncrementPercentage = market.minBidIncrementPercentage();
        return amount + ((amount * minBidIncrementPercentage) / 100);
    }

    /**
     * @notice Query the current highest bidder for this auction
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 auctionId)
        external
        view
        override
        returns (address)
    {
        require(
            auctionExists(auctionId),
            "NounsMarketWrapper::getCurrentHighestBidder: Auction not active"
        );

        (, , , , address payable bidder, ) = market.auction();
        return bidder;
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        // line 104 of Nouns Auction House, createBid() function
        (bool success, bytes memory returnData) = address(market).call{
            value: bidAmount
        }(abi.encodeWithSignature("createBid(uint256)", auctionId));
        require(success, string(returnData));
    }

    /**
     * @notice Determine whether the auction has been finalized
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId)
        external
        view
        override
        returns (bool)
    {
        (uint256 currentAuctionId, , , , , bool settled) = market.auction();
        bool settledNormally = auctionId != currentAuctionId;
        bool settledWhenPaused = auctionId == currentAuctionId && settled;
        return settledNormally || settledWhenPaused;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(
        uint256 /* auctionId */
    ) external override {
        if (market.paused()) {
            market.settleAuction();
        } else {
            market.settleCurrentAndCreateNewAuction();
        }
    }
}
