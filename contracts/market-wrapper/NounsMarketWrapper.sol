// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

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
    // ============ Internal Immutables ============

    INounsAuctionHouse internal immutable market;

    // ======== Constructor =========

    constructor(address _nounsAuctionHouse) {
        market = INounsAuctionHouse(_nounsAuctionHouse);
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether there is an existing auction
     * for this token is active
     * @return TRUE if the auction exists
     */
    function auctionExists(uint256 auctionId)
      public
      view
      override
      returns (bool)
    {
        (uint256 currentAuctionId, , , , , ) = market.auction();
        return auctionId == currentAuctionId;
    }

    /**
     * @notice Determine whether the given auctionId and tokenId is active.
     * We ignore nftContract since it is static for all nouns auctions.
     * @return TRUE if the auctionId and tokenId matches the active auction
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address /* nftContract */,
        uint256 tokenId
    ) public view override returns (bool) {
        (uint256 currentAuctionId, , , , , ) = market.auction();
        return currentAuctionId == tokenId && currentAuctionId == auctionId;
    }

    /**
     * @notice Calculate the minimum next bid for the active auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 /* auctionId */)
      external
      view
      override
      returns (uint256)
    {
        (, uint256 amount, , , address payable bidder, ) = market.auction();
        if (bidder == address(0)) {
            // if there are NO bids, the minimum bid is 1 wei (any amount > 0)
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
    function getCurrentHighestBidder(uint256 /* auctionId */)
      external
      view
      override
      returns (address)
    {
        (, , , , address payable bidder, ) = market.auction();
        return bidder;
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        // line 85 of Nouns Auction House, createBid() function
        (bool success, bytes memory returnData) =
        address(market).call{value: bidAmount}(
            abi.encodeWithSignature(
                "createBid(uint256)",
                auctionId
            )
        );
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
    function finalize(uint256 /* auctionId */) external override {
        if (market.paused()) {
            market.settleAuction();
        } else {
            market.settleCurrentAndCreateNewAuction();
        }
    }
}
