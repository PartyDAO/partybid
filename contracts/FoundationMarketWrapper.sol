// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {IMarketWrapper} from "./interfaces/IMarketWrapper.sol";
import {IFoundationMarket} from "./interfaces/IFoundationMarket.sol";

/**
 * @title FoundationMarketWrapper
 * @author Anna Carroll
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Foundation's NFT Market
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
     * @notice Get the address of the Foundation Market
     * @return address of the Foundation market
     */
    function getMarketAddress() external view override returns (address) {
        return address(market);
    }

    /**
     * @notice Determine whether there is an existing auction
     * for this token on the Foundation market
     * @return TRUE if the auction exists
     */
    function auctionExists(address nftContract, uint256 tokenId)
        external
        view
        override
        returns (bool)
    {
        uint256 _auctionId =
            market.getReserveAuctionIdFor(nftContract, tokenId);
        return _auctionId != 0;
    }

    /**
     * @notice Get the auctionId for this token on the Foundation market
     * @return auctionId
     */
    function getAuctionId(address nftContract, uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        return market.getReserveAuctionIdFor(nftContract, tokenId);
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
        return market.getMinBidAmount(auctionId);
    }

    /**
     * @notice Encode the data to call the placeBid function
     * @return bid calldata
     */
    function getBidData(
        uint256 auctionId,
        uint256 bidAmount // solhint-disable-line no-unused-vars
    ) external pure override returns (bytes memory) {
        return abi.encodeWithSignature("placeBid(uint256)", auctionId);
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
        IFoundationMarket.ReserveAuction memory _auction =
            market.getReserveAuction(auctionId);
        // check if the auction has already been finalized
        // by seeing if it has been deleted from the contract
        return _auction.amount == 0;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external override {
        // will revert if auction has not started or still in progress
        market.finalizeReserveAuction(auctionId);
    }
}
