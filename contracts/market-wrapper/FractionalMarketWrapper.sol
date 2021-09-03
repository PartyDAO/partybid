// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports ============
import {IERC721VaultFactory} from "../external/interfaces/IERC721VaultFactory.sol";
import {IERC721TokenVault} from "../external/interfaces/IERC721TokenVault.sol";
import {IFractionalSettings} from "../external/interfaces/IFractionalSettings.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FractionalMarketWrapper
 * @author Apoorv Lathey
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional's Token Vaults
 */
contract FractionalMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============

    IERC721VaultFactory public immutable market;

    // ======== Constructor =========

    constructor(address _fractionalERC721VaultFactory) {
        market = IERC721VaultFactory(_fractionalERC721VaultFactory);
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether there is an existing auction
     * for this token on the market
     * @return TRUE if the auction exists
     */
    function auctionExists(uint256 auctionId) public view returns (bool) {
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        uint8 auctionState = tokenVault.auctionState();
        if (auctionState == 0) {
            // line 319 of ERC721TokenVault
            IFractionalSettings settings = IFractionalSettings(
                tokenVault.settings()
            );
            uint256 minVotePercentage = settings.minVotePercentage();
            uint256 totalSupply = tokenVault.totalSupply();
            uint256 votingTokens = tokenVault.votingTokens();

            // auction can be initiated via start() in ERC721TokenVault,
            // if enough votes reached
            return (votingTokens * 1000 >= minVotePercentage * totalSupply);
        } else if (auctionState == 1) {
            uint256 auctionEnd = tokenVault.auctionEnd();
            return block.timestamp < auctionEnd;
        }

        return false;
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
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        address _nftContract = tokenVault.token();
        uint256 _tokenId = tokenVault.id();
        return
            _nftContract == nftContract &&
            _tokenId == tokenId &&
            auctionExists(auctionId);
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
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        uint8 auctionState = tokenVault.auctionState();
        if (auctionState == 0) {
            return tokenVault.reservePrice();
        } else {
            IFractionalSettings settings = IFractionalSettings(
                tokenVault.settings()
            );
            uint256 livePrice = tokenVault.livePrice();
            uint256 increase = settings.minBidIncrease() + 1000;
            // line 334 of ERC721TokenVault
            return (livePrice * increase) / 1000;
        }
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
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        return tokenVault.winning();
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        uint8 auctionState = tokenVault.auctionState();
        if (auctionState == 0) {
            // line 316 of ERC721TokenVault, start() function
            (bool success, bytes memory returnData) = address(tokenVault).call{
                value: bidAmount
            }(abi.encodeWithSignature("start()"));
            require(success, string(returnData));
        } else {
            // line 331 of ERC721TokenVault, bid() function
            (bool success, bytes memory returnData) = address(tokenVault).call{
                value: bidAmount
            }(abi.encodeWithSignature("bid()"));
            require(success, string(returnData));
        }
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
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        uint8 auctionState = tokenVault.auctionState();
        // auction is considered finalized if
        // 1. the voters backed off now, so the auction can't be initiated
        // 2. the auction got ended
        // 3. the vault got redeemed (hence, no bids were placed)

        if (auctionState == 0) {
            // line 319 of ERC721TokenVault
            IFractionalSettings settings = IFractionalSettings(
                tokenVault.settings()
            );
            uint256 minVotePercentage = settings.minVotePercentage();
            uint256 totalSupply = tokenVault.totalSupply();
            uint256 votingTokens = tokenVault.votingTokens();

            // auction **cannot** be initiated via start() in ERC721TokenVault,
            return (votingTokens * 1000 < minVotePercentage * totalSupply);
        }

        return auctionState == 2 || auctionState == 3;
    }

    /**
     * @notice Finalize the results of the auction
     * @dev gets called when block.timestamp >= auctionEnd
     */
    function finalize(uint256 auctionId) external override {
        IERC721TokenVault tokenVault = IERC721TokenVault(
            market.vaults(auctionId)
        );
        tokenVault.end();
    }
}
