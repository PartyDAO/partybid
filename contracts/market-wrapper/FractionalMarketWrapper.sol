// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports ============
import {IERC721TokenVault} from "../external/interfaces/IERC721TokenVault.sol";
import {ISettings} from "../external/fractional/Interfaces/ISettings.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title FractionalMarketWrapper
 * @author 0xfoobar
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of Fractional's auctions
 */
contract FractionalMarketWrapper is IMarketWrapper {
    // ============ Public Immutables ============

    ISettings public immutable settings = ISettings(0xE0FC79183a22106229B84ECDd55cA017A07eddCa);

    uint256 public registrationCounter = 1; // The zero value is a sentinel for not existing
    mapping(uint256 => address) public auctionToAddress;
    mapping(address => uint256) public addressToAuction;

    // ======== Constructor =========

    constructor(address /* _fractional */) {}

    // ======== External Functions =========

    /**
     * @notice Register a Fractional Vault within the contract
     */
    function registerVault(
        address nftContract
    ) public {
        require(addressToAuction[nftContract] == 0, "Vault already registered");
        auctionToAddress[registrationCounter] = nftContract;
        addressToAuction[nftContract] = registrationCounter;
        registrationCounter += 1;
    }

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
        address marketAddress = auctionToAddress[auctionId];
        if (marketAddress == address(0)) {
            return false;
        } else {
            uint auctionState = uint(IERC721TokenVault(marketAddress).auctionState());
            return (auctionState == 0 || auctionState == 1); // See https://github.com/fractional-company/contracts/blob/master/src/ERC721TokenVault.sol#L55
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
        return (IERC721TokenVault(auctionToAddress[auctionId]).livePrice() * (settings.minBidIncrease() + 1000)) / 1000;
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
        return IERC721TokenVault(auctionToAddress[auctionId]).winning();
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external override {
        (bool success, bytes memory returnData) =
        auctionToAddress[auctionId].call{value: bidAmount}(
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
        return uint(IERC721TokenVault(auctionToAddress[auctionId]).auctionState()) == 3;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 /* auctionId */) external override {
        // if (market.paused()) {
        //     market.settleAuction();
        // } else {
        //     market.settleCurrentAndCreateNewAuction();
        // }
    }
}
