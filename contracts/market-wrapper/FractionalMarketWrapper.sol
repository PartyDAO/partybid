// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports ============
import {IERC721TokenVault, TokenState} from "../external/interfaces/IERC721TokenVault.sol";
import {ISettings} from "../external/interfaces/IFractionalSettings.sol";
import {IERC721VaultFactory} from "../external/interfaces/IERC721VaultFactory.sol";
import {IWETH} from "../external/fractional/Interfaces/IWETH.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FractionalMarketWrapper
 * @author Saw-mon and Natalie (@sw0nt) + Anna Carroll + Fractional Team
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional Token Vault
 */
contract FractionalMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============

    IERC721VaultFactory public immutable fractionalVault;
    IWETH public immutable weth;

    // ======== Constructor =========

    constructor(address _fractionalVault, address _weth) {
        fractionalVault = IERC721VaultFactory(_fractionalVault);
        weth = IWETH(_weth);
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether there is an existing, inactive aution which can be started
     * @return TRUE if the auction state is inactive but there are enough voting tokens to start it. 
     */
    function auctionIsInActiveButCanBeStarted(uint256 auctionId) public view returns(bool) {
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));
        ISettings tokenSettings = ISettings(tokenVault.settings());
        return tokenVault.auctionState() == TokenState.inactive && tokenVault.votingTokens() * 1000 >= tokenSettings.minVotePercentage() * tokenVault.totalSupply();
    }

    /**
     * @notice Determine whether there is an existing, active aution which is not ended
     * @return TRUE if the auction state is live and auction end time is less than block timestamp
     */
    function auctionIsLiveAndNotEnded(uint256 auctionId) public view returns(bool) {
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));

        return tokenVault.auctionState() == TokenState.live && tokenVault.auctionEnd() > block.timestamp;
    }

    /**
     * @notice Determine whether there is an existing, active auction
     * for this token.
     * @return TRUE if the auction exists
     */
    function auctionExists(uint256 auctionId) public view returns (bool) {
        return auctionIsInActiveButCanBeStarted(auctionId) || auctionIsLiveAndNotEnded(auctionId);
    }

    /**
     * @notice Determine whether the given auctionId and tokenId is active.
     * @return TRUE if the auctionId and tokenId matches the active auction
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) public view override returns (bool) {
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));
        return tokenVault.id() == tokenId && tokenVault.token() == nftContract && auctionExists(auctionId);
    }

    /**
     * @notice Calculate the minimum next bid for the active auction. If
     * auction is inactive and can be started we will return the reservePrice
     * otherwise the minimum bid amount needs to be calculated according to
     * logic.
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
            "FractionalMarketWrapper::getMinimumBid: Auction not active"
        );

        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));
        
        if(auctionIsInActiveButCanBeStarted(auctionId)) {
            return tokenVault.reservePrice();
        }

        uint256 increase = ISettings(tokenVault.settings()).minBidIncrease() + 1000;

        /**
         * minbound = 1000 * k + r, where 0 <= r < 1000 so,
         * minBid = k, but if r > 0, minBid * 1000 < minBound,
         * in that case we need to increment minBid by 1. Since
         * minBid * 1000 = (k+1) * 1000 > 1000 * k + r = minBound
         */
        uint256 minbound = tokenVault.livePrice() * increase;
        uint256 minBid = minbound / 1000;

        if(minBid * 1000 < minbound) {
            minBid += 1;
        }

        return minBid;
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
            "FractionalMarketWrapper::getCurrentHighestBidder: Auction not active"
        );

        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));

        return tokenVault.winning();
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        // @dev since PartyBid recieves weth from Fractional when another entity outbids, we will
        // transfer that wETH to the PartyBid's ETH balance. The next line will be executed in the context
        // of PartyBid contract since it uses a DELEGATECALL to this bid function.
        weth.withdraw(weth.balanceOf(address(this)));
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));

        string memory endpoint = auctionIsInActiveButCanBeStarted(auctionId) ? "start()" : "bid()";

        // line 331 of Fractional ERC721TokenVault, bid() function
        (bool success, bytes memory returnData) = address(tokenVault).call{
            value: bidAmount
        }(abi.encodeWithSignature(endpoint));
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
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));

        return tokenVault.auctionState() == TokenState.ended;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(
        uint256 auctionId
    ) external override {
        IERC721TokenVault tokenVault = IERC721TokenVault(fractionalVault.vaults(auctionId));

        tokenVault.end();
    }
}
