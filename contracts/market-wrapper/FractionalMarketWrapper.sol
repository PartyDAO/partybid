// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports ============
import {TokenVault} from "../external/fractional/ERC721TokenVault.sol";
import {ERC721VaultFactory} from "../external/fractional/ERC721VaultFactory.sol";
import {Settings} from "../external/fractional/Settings.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FractionalMarketWrapper
 * @author Jacob Frantz + gakonst + 0xvick
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional's TokenVault
 * @dev This only works for v1.1 of Fractional's ERC721VaultFactory
 * because current version of PartyBid.sol must receive ETH not WETH
 */
contract FractionalMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============
    ERC721VaultFactory public immutable vaultFactory;
    Settings public immutable settings;

    // ======== Constructor =========
    constructor(
        address _vaultFactory
    ) {
        vaultFactory = ERC721VaultFactory(_vaultFactory);
        settings = Settings(vaultFactory.settings());
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether auctionId corresponds to an
     * ERC721TokenVault that matches the nftContract + tokenId
     * and can be bid on. In Fractional's vaults, auctions
     * can be `start()`ed only if enough people voted on a 
     * reserve price, and after that can be `bid()` until
     * time runs out.
     * @return TRUE if the auction exists
     * @param auctionId By convention an auctionId is the vaulId of the auction stored by the ERC721VaultFactory
     */    
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) external view returns (bool) 
    {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        
        // 1. the auction ID matches the token
        if (auction.token() != nftContract || auction.id() != tokenId) {
            return false;
        }

        // 2. the auctionId refers to an auction that will accept bids
        TokenVault.State auctionState = auction.auctionState();
        if (auctionState == TokenVault.State.inactive) {
            // we'd be `start()`ing it
            // see ERC721TokenVault, line 324
            return auction.votingTokens() * 1000 >=
                settings.minVotePercentage() * auction.totalSupply();
        } else if (auctionState == TokenVault.State.live) {
            // we'd be `bid()`ing on it
            return (block.timestamp < auction.auctionEnd());
        } else {
            // auction is State.ended or State.redeemed,
            // which means it is not an active auction
            // and can't be started
            return false;
        }
    }

    /**
     * @notice Query the current highest bidder for this auction
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 auctionId)
        external
        view
        returns (address) {
            TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
            return auction.winning();
        }

    /**
     * @notice Calculate the minimum next bid for the active auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId) external view returns (uint256) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        
        TokenVault.State state = auction.auctionState();
        if (state == TokenVault.State.inactive) {
            return auction.reservePrice();
        } else if (state == TokenVault.State.live){
            // see ERC721TokenVault, line 338:339
            uint256 increase = settings.minBidIncrease() + 1000;
            uint256 toAdd = (auction.livePrice() * increase) % 1000 == 0 ? 0 : 1; // should this be different?
            return ((auction.livePrice() * increase) / 1000) + toAdd;
        } else {
            // auction cannot be bid on, this shouldn't be reached
            require(false, "FractionalMarketWrapper::getMinimumBid: auction cant be bid");
            return 0;
        }
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        TokenVault.State auctionState = auction.auctionState();

        if (auctionState == TokenVault.State.inactive) {
            auction.start{value: bidAmount}();
        } else if (auctionState == TokenVault.State.live) {
            auction.bid{value: bidAmount}();
        } else {
            require(false, "FractionalMarketWrapper::bid: auction cant be bid");
        }
    }

    /**
     * @notice Determine whether the auction has been finalized
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId) external view returns (bool) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        return auction.auctionState() == TokenVault.State.ended;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        auction.end();

    }
}