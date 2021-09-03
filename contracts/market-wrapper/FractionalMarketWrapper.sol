// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ============ External Imports ============
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {TokenVault} from "../external/fractional/ERC721TokenVault.sol";
import {ERC721VaultFactory} from "../external/fractional/ERC721VaultFactory.sol";
import {Settings} from "../external/fractional/Settings.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FractionalMarketWrapper
 * @author vick9453, Jacob Frantz
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional's TokenVaults
 * Original Fractional TokenVault code: https://github.com/fractional-company/contracts/blob/master/src/ERC721TokenVault.sol
 */
contract FractionalMarketWrapper is IMarketWrapper {
    using SafeMath for uint256;

    // ============ Internal Immutables ============

    ERC721VaultFactory internal immutable vaultFactory;
    Settings internal immutable settings;

    // ======== Constructor =========

    constructor(address _fractionalVaultFactory) {
        vaultFactory = ERC721VaultFactory(_fractionalVaultFactory);
        settings = Settings(
            ERC721VaultFactory(_fractionalVaultFactory).settings()
        );
    }

// ======== External Functions =========

    /**
     * @notice Given the auctionId, nftContract, and tokenId, check that:
     * 1. the auction ID matches the token
     * referred to by tokenId + nftContract
     * 2. the auctionId refers to an *ACTIVE* auction
     * (e.g. an auction that will accept bids)
     * within this market contract
     * 3. any additional validation to ensure that
     * a PartyBid can bid on this auction
     * (ex: if the market allows arbitrary bidding currencies,
     * check that the auction currency is ETH)
     * Note: This function probably should have been named "isValidAuction"
     * @dev Called in PartyBid.sol in `initialize` at line 174
     * @return TRUE if the auction is valid
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) external override view returns (bool) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));

        if (auction.token() != nftContract || auction.id() != tokenId) {
            return false;
        }
        TokenVault.State auctionState = auction.auctionState();
        if (auctionState == TokenVault.State.inactive) {
            // must be able to start() auction. see ERC721TokenVault.sol, line 316
            return (auction.votingTokens() * 1000 >= 
                    settings.minVotePercentage() * auction.totalSupply());
        
        } else if (auctionState == TokenVault.State.live) {
            // must be able to bid() in auction. see ERC721TokenVault.sol, line 331
            return (block.timestamp < auction.auctionEnd());
        
        } else {
            return false;
        }
    }

        /**
     * @notice Calculate the minimum next bid for this auction.
     * PartyBid contracts always submit the minimum possible
     * bid that will be accepted by the Market contract.
     * usually, this is either the reserve price (if there are no bids)
     * or a certain percentage increase above the current highest bid
     * @dev Called in PartyBid.sol in `bid` at line 251
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 auctionId) external override view returns (uint256) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        TokenVault.State auctionState = auction.auctionState();
        require(auctionState == TokenVault.State.inactive || auctionState == TokenVault.State.live, "can't bid");
        
        if (auctionState == TokenVault.State.inactive) {
            return auction.reservePrice();
        } else if (auctionState == TokenVault.State.live) {
            uint256 increase = settings.minBidIncrease() + 1000;
            return (auction.livePrice() * increase / 1000);
        } else {
            return 0; // never happens
        }
    }

    /**
     * @notice Query the current highest bidder for this auction
     * It is assumed that there is always 1 winning highest bidder for an auction
     * This is used to ensure that PartyBid cannot outbid itself if it is already winning
     * @dev Called in PartyBid.sol in `bid` at line 241
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 auctionId)
        external 
        override
        view
        returns (address) {
            TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
            address winning = auction.winning();
            require (address(0) != winning, "no auction");

            return winning;
        }

    /**
     * @notice Submit bid to Market contract
     * @dev Called in PartyBid.sol in `bid` at line 259
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
            TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
            TokenVault.State auctionState = auction.auctionState();

            if (auctionState == TokenVault.State.inactive) {
                auction.start{value: bidAmount}();
            } else if (auctionState == TokenVault.State.live) {
                auction.bid{value: bidAmount}();
            }
        }

    /**
     * @notice Determine whether the auction has been finalized
     * Used to check if it is still possible to bid
     * And to determine whether the PartyBid should finalize the auction
     * @dev Called in PartyBid.sol in `bid` at line 247
     * @dev and in `finalize` at line 288
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId) external override view returns (bool) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        TokenVault.State auctionState = auction.auctionState();
        return 
            (auctionState == TokenVault.State.live && block.timestamp < auction.auctionEnd())
            || (auctionState == TokenVault.State.ended);
    }

    /**
     * @notice Finalize the results of the auction
     * on the Market contract
     * It is assumed  that this operation is performed once for each auction,
     * that after it is done the auction is over and the NFT has been
     * transferred to the auction winner.
     * @dev Called in PartyBid.sol in `finalize` at line 289
     */
    function finalize(uint256 auctionId) external override {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        auction.end();
    }
}
