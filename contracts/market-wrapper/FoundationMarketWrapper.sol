// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports ============
import {IFoundationMarket} from "../external/interfaces/IFoundationMarket.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FoundationMarketWrapper
 * @author Anna Carroll
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Foundation's NFT Market
 * Original Foundation NFT Market code: https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code
 */
contract FoundationMarketWrapper is IMarketWrapper {
    // ============ Internal Immutables ============

    IFoundationMarket internal immutable market;

    // ======== Constructor =========

    constructor(address _foundationMarket) {
        market = IFoundationMarket(_foundationMarket);
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether there is an existing auction
     * for this token on the market
     * @return TRUE if the auction exists
     */
    function auctionExists(uint256 auctionId)
        public
        view
        returns (bool)
    {
        // line 219 of NFTMarketReserveAuction, logic within placeBid() function (not exposed publicly)
        IFoundationMarket.ReserveAuction memory _auction =
            market.getReserveAuction(auctionId);
        return _auction.amount != 0;
    }

    /**
     * @notice Determine whether the given auctionId is
     * an auction for the tokenId + nftContract
     * @return TRUE if the auctionId matches the tokenId + nftContract
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) public view override returns (bool) {
        return auctionId == market.getReserveAuctionIdFor(nftContract, tokenId);
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
        // line 279 of NFTMarketReserveAuction, getMinBidAmount() function
        IFoundationMarket.ReserveAuction memory _auction =
            market.getReserveAuction(auctionId);
        return _auction.bidder;
    }

    /**
     * @notice Calculate the minimum next bid for this auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId)
        external
        view
        override
        returns (uint256)
    {
        // line 279 of NFTMarketReserveAuction, getMinBidAmount() function
        return market.getMinBidAmount(auctionId);
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        // line 217 of NFTMarketReserveAuction, placeBid() function
        (bool success, bytes memory returnData) =
            address(market).call{value: bidAmount}(
                abi.encodeWithSignature("placeBid(uint256)", auctionId)
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
        // line 266 of NFTMarketReserveAuction,
        // the auction is deleted at the end of the finalizeReserveAuction() function
        // since we checked that the auction DID exist when we deployed the partyBid,
        // if it no longer exists that means the auction has been finalized.
        return !auctionExists(auctionId);
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external override {
        // line 260 of finalizeReserveAuction, finalizeReserveAuction() function
        // will revert if auction has not started or still in progress
        market.finalizeReserveAuction(auctionId);
    }
}
