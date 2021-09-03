// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports ============
import {IERC721VaultFactory} from "../external/interfaces/IERC721VaultFactory.sol";
import {IERC721TokenVault} from "../external/interfaces/IERC721TokenVault.sol";
import {ISettings} from "../external/fractional/Interfaces/ISettings.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

import "hardhat/console.sol";

/**
 * @title FractionalMarketWrapper
 * @author 0xfoobar
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional's auctions
 */
contract FractionalMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============

    IERC721VaultFactory public immutable vaultFactory;
    ISettings public immutable settings;

    // ======== Constructor =========

    constructor(address _fractional) {
        vaultFactory = IERC721VaultFactory(_fractional);
        settings = ISettings(IERC721VaultFactory(_fractional).settings());
    }

    // ======== External Functions =========

    /**
     * @notice Determine whether the given auctionId and tokenId is active.
     * We ignore nftContract since it is static for all nouns auctions.
     * @return TRUE if the auctionId and tokenId matches the active auction
     */
    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) public view override returns (bool) {
        address marketAddress = vaultFactory.vaults(auctionId);
        console.log("vault count is %s at %s", vaultFactory.vaultCount(), address(this));
        console.log("auctionId is %s, address is %s", auctionId, marketAddress);
        if (marketAddress == address(0)) {
            return false;
        } else {
            return true;
            IERC721TokenVault vault = IERC721TokenVault(vaultFactory.vaults(auctionId));
            IERC721TokenVault.State auctionState = IERC721TokenVault(marketAddress).auctionState();
            return (
                auctionState == IERC721TokenVault.State.inactive
                || (auctionState == IERC721TokenVault.State.live && block.timestamp < vault.auctionEnd())
                || auctionState == IERC721TokenVault.State.ended
            ); // See https://github.com/fractional-company/contracts/blob/master/src/ERC721TokenVault.sol#L55
        }
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
        return (IERC721TokenVault(vaultFactory.vaults(auctionId)).livePrice() * (settings.minBidIncrease() + 1000)) / 1000;
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
        return IERC721TokenVault(vaultFactory.vaults(auctionId)).winning();
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        (bool success, bytes memory returnData) =
        (vaultFactory.vaults(auctionId)).call{value: bidAmount}(
            abi.encodeWithSignature(
                "bid())"
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
        return IERC721TokenVault(vaultFactory.vaults(auctionId)).auctionState() == IERC721TokenVault.State.ended;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external override {
        IERC721TokenVault(vaultFactory.vaults(auctionId)).end();
    }
}
