// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0

pragma solidity ^0.7.0;
pragma abicoder v2; // solhint-disable-line

import "@openzeppelin/contracts-upgradeable2/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable2/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable2/utils/ReentrancyGuardUpgradeable.sol";

import "./Constants.sol";
import "./NFTMarketCore.sol";
import "./NFTMarketFees.sol";
import "./SendValueWithFallbackWithdraw.sol";
import "./NFTMarketAuction.sol";
import "./roles/FoundationAdminRole.sol";
import "./AccountMigration.sol";

/**
 * @notice Manages a reserve price auction for NFTs.
 */
abstract contract NFTMarketReserveAuction is
Constants,
FoundationAdminRole,
AccountMigration,
NFTMarketCore,
ReentrancyGuardUpgradeable,
SendValueWithFallbackWithdraw,
NFTMarketFees,
NFTMarketAuction
{
    using SafeMathUpgradeable for uint256;

    struct ReserveAuction {
        address nftContract;
        uint256 tokenId;
        address payable seller;
        uint256 duration;
        uint256 extensionDuration;
        uint256 endTime;
        address payable bidder;
        uint256 amount;
    }

    mapping(address => mapping(uint256 => uint256)) private nftContractToTokenIdToAuctionId;
    mapping(uint256 => ReserveAuction) private auctionIdToAuction;

    uint256 private _minPercentIncrementInBasisPoints;

    // This variable was used in an older version of the contract, left here as a gap to ensure upgrade compatibility
    uint256 private ______gap_was_maxBidIncrementRequirement;

    uint256 private _duration;

    // These variables were used in an older version of the contract, left here as gaps to ensure upgrade compatibility
    uint256 private ______gap_was_extensionDuration;
    uint256 private ______gap_was_goLiveDate;

    // Cap the max duration so that overflows will not occur
    uint256 private constant MAX_MAX_DURATION = 1000 days;

    uint256 private constant EXTENSION_DURATION = 15 minutes;

    event ReserveAuctionConfigUpdated(
        uint256 minPercentIncrementInBasisPoints,
        uint256 maxBidIncrementRequirement,
        uint256 duration,
        uint256 extensionDuration,
        uint256 goLiveDate
    );

    event ReserveAuctionCreated(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 duration,
        uint256 extensionDuration,
        uint256 reservePrice,
        uint256 auctionId
    );
    event ReserveAuctionUpdated(uint256 indexed auctionId, uint256 reservePrice);
    event ReserveAuctionCanceled(uint256 indexed auctionId);
    event ReserveAuctionBidPlaced(uint256 indexed auctionId, address indexed bidder, uint256 amount, uint256 endTime);
    event ReserveAuctionFinalized(
        uint256 indexed auctionId,
        address indexed seller,
        address indexed bidder,
        uint256 f8nFee,
        uint256 creatorFee,
        uint256 ownerRev
    );
    event ReserveAuctionCanceledByAdmin(uint256 indexed auctionId, string reason);
    event ReserveAuctionSellerMigrated(
        uint256 indexed auctionId,
        address indexed originalSellerAddress,
        address indexed newSellerAddress
    );

    modifier onlyValidAuctionConfig(uint256 reservePrice) {
        require(reservePrice > 0, "NFTMarketReserveAuction: Reserve price must be at least 1 wei");
        _;
    }

    /**
     * @notice Returns auction details for a given auctionId.
     */
    function getReserveAuction(uint256 auctionId) public view returns (ReserveAuction memory) {
        return auctionIdToAuction[auctionId];
    }

    /**
     * @notice Returns the auctionId for a given NFT, or 0 if no auction is found.
     * @dev If an auction is canceled, it will not be returned. However the auction may be over and pending finalization.
     */
    function getReserveAuctionIdFor(address nftContract, uint256 tokenId) public view returns (uint256) {
        return nftContractToTokenIdToAuctionId[nftContract][tokenId];
    }

    /**
     * @dev Returns the seller that put a given NFT into escrow,
     * or bubbles the call up to check the current owner if the NFT is not currently in escrow.
     */
    function _getSellerFor(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    override
    returns (address payable)
    {
        address payable seller = auctionIdToAuction[nftContractToTokenIdToAuctionId[nftContract][tokenId]].seller;
        if (seller == address(0)) {
            return super._getSellerFor(nftContract, tokenId);
        }
        return seller;
    }

    /**
     * @notice Returns the current configuration for reserve auctions.
     */
    function getReserveAuctionConfig() public view returns (uint256 minPercentIncrementInBasisPoints, uint256 duration) {
        minPercentIncrementInBasisPoints = _minPercentIncrementInBasisPoints;
        duration = _duration;
    }

    function _initializeNFTMarketReserveAuction() internal {
        _duration = 24 hours; // A sensible default value
    }

    function _updateReserveAuctionConfig(uint256 minPercentIncrementInBasisPoints, uint256 duration) internal {
        require(minPercentIncrementInBasisPoints <= BASIS_POINTS, "NFTMarketReserveAuction: Min increment must be <= 100%");
        // Cap the max duration so that overflows will not occur
        require(duration <= MAX_MAX_DURATION, "NFTMarketReserveAuction: Duration must be <= 1000 days");
        require(duration >= EXTENSION_DURATION, "NFTMarketReserveAuction: Duration must be >= EXTENSION_DURATION");
        _minPercentIncrementInBasisPoints = minPercentIncrementInBasisPoints;
        _duration = duration;

        // We continue to emit unused configuration variables to simplify the subgraph integration.
        emit ReserveAuctionConfigUpdated(minPercentIncrementInBasisPoints, 0, duration, EXTENSION_DURATION, 0);
    }

    /**
     * @notice Creates an auction for the given NFT.
     * The NFT is held in escrow until the auction is finalized or canceled.
     */
    function createReserveAuction(
        address nftContract,
        uint256 tokenId,
        uint256 reservePrice
    ) public onlyValidAuctionConfig(reservePrice) nonReentrant {
        // If an auction is already in progress then the NFT would be in escrow and the modifier would have failed
        uint256 auctionId = _getNextAndIncrementAuctionId();
        nftContractToTokenIdToAuctionId[nftContract][tokenId] = auctionId;
        auctionIdToAuction[auctionId] = ReserveAuction(
            nftContract,
            tokenId,
            msg.sender,
            _duration,
            EXTENSION_DURATION,
            0, // endTime is only known once the reserve price is met
            address(0), // bidder is only known once a bid has been placed
            reservePrice
        );

        IERC721Upgradeable(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit ReserveAuctionCreated(
            msg.sender,
            nftContract,
            tokenId,
            _duration,
            EXTENSION_DURATION,
            reservePrice,
            auctionId
        );
    }

    /**
     * @notice If an auction has been created but has not yet received bids, the configuration
     * such as the reservePrice may be changed by the seller.
     */
    function updateReserveAuction(uint256 auctionId, uint256 reservePrice) public onlyValidAuctionConfig(reservePrice) {
        ReserveAuction storage auction = auctionIdToAuction[auctionId];
        require(auction.seller == msg.sender, "NFTMarketReserveAuction: Not your auction");
        require(auction.endTime == 0, "NFTMarketReserveAuction: Auction in progress");

        auction.amount = reservePrice;

        emit ReserveAuctionUpdated(auctionId, reservePrice);
    }

    /**
     * @notice If an auction has been created but has not yet received bids, it may be canceled by the seller.
     * The NFT is returned to the seller from escrow.
     */
    function cancelReserveAuction(uint256 auctionId) public nonReentrant {
        ReserveAuction memory auction = auctionIdToAuction[auctionId];
        require(auction.seller == msg.sender, "NFTMarketReserveAuction: Not your auction");
        require(auction.endTime == 0, "NFTMarketReserveAuction: Auction in progress");

        delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
        delete auctionIdToAuction[auctionId];

        IERC721Upgradeable(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);

        emit ReserveAuctionCanceled(auctionId);
    }

    /**
     * @notice A bidder may place a bid which is at least the value defined by `getMinBidAmount`.
     * If this is the first bid on the auction, the countdown will begin.
     * If there is already an outstanding bid, the previous bidder will be refunded at this time
     * and if the bid is placed in the final moments of the auction, the countdown may be extended.
     */
    function placeBid(uint256 auctionId) public payable nonReentrant {
        ReserveAuction storage auction = auctionIdToAuction[auctionId];
        require(auction.amount != 0, "NFTMarketReserveAuction: Auction not found");

        if (auction.endTime == 0) {
            // If this is the first bid, ensure it's >= the reserve price
            require(auction.amount <= msg.value, "NFTMarketReserveAuction: Bid must be at least the reserve price");
        } else {
            // If this bid outbids another, confirm that the bid is at least x% greater than the last
            require(auction.endTime >= block.timestamp, "NFTMarketReserveAuction: Auction is over");
            require(auction.bidder != msg.sender, "NFTMarketReserveAuction: You already have an outstanding bid");
            uint256 minAmount = _getMinBidAmountForReserveAuction(auction.amount);
            require(msg.value >= minAmount, "NFTMarketReserveAuction: Bid amount too low");
        }

        if (auction.endTime == 0) {
            auction.amount = msg.value;
            auction.bidder = msg.sender;
            // On the first bid, the endTime is now + duration
            auction.endTime = block.timestamp + auction.duration;
        } else {
            // Cache and update bidder state before a possible reentrancy (via the value transfer)
            uint256 originalAmount = auction.amount;
            address payable originalBidder = auction.bidder;
            auction.amount = msg.value;
            auction.bidder = msg.sender;

            // When a bid outbids another, check to see if a time extension should apply.
            if (auction.endTime - block.timestamp < auction.extensionDuration) {
                auction.endTime = block.timestamp + auction.extensionDuration;
            }

            // Refund the previous bidder
            _sendValueWithFallbackWithdrawWithLowGasLimit(originalBidder, originalAmount);
        }

        emit ReserveAuctionBidPlaced(auctionId, msg.sender, msg.value, auction.endTime);
    }

    /**
     * @notice Once the countdown has expired for an auction, anyone can settle the auction.
     * This will send the NFT to the highest bidder and distribute funds.
     */
    function finalizeReserveAuction(uint256 auctionId) public nonReentrant {
        ReserveAuction memory auction = auctionIdToAuction[auctionId];
        require(auction.endTime > 0, "NFTMarketReserveAuction: Auction was already settled");
        require(auction.endTime < block.timestamp, "NFTMarketReserveAuction: Auction still in progress");

        delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
        delete auctionIdToAuction[auctionId];

        IERC721Upgradeable(auction.nftContract).transferFrom(address(this), auction.bidder, auction.tokenId);

        (uint256 f8nFee, uint256 creatorFee, uint256 ownerRev) =
        _distributeFunds(auction.nftContract, auction.tokenId, auction.seller, auction.amount);

        emit ReserveAuctionFinalized(auctionId, auction.seller, auction.bidder, f8nFee, creatorFee, ownerRev);
    }

    /**
     * @notice Returns the minimum amount a bidder must spend to participate in an auction.
     */
    function getMinBidAmount(uint256 auctionId) public view returns (uint256) {
        ReserveAuction storage auction = auctionIdToAuction[auctionId];
        if (auction.endTime == 0) {
            return auction.amount;
        }
        return _getMinBidAmountForReserveAuction(auction.amount);
    }

    /**
     * @dev Determines the minimum bid amount when outbidding another user.
     */
    function _getMinBidAmountForReserveAuction(uint256 currentBidAmount) private view returns (uint256) {
        uint256 minIncrement = currentBidAmount.mul(_minPercentIncrementInBasisPoints) / BASIS_POINTS;
        if (minIncrement == 0) {
            // The next bid must be at least 1 wei greater than the current.
            return currentBidAmount.add(1);
        }
        return minIncrement.add(currentBidAmount);
    }

    /**
     * @notice Allows Foundation to cancel an auction, refunding the bidder and returning the NFT to the seller.
     * This should only be used for extreme cases such as DMCA takedown requests. The reason should always be provided.
     */
    function adminCancelReserveAuction(uint256 auctionId, string memory reason) public onlyFoundationAdmin {
        require(bytes(reason).length > 0, "NFTMarketReserveAuction: Include a reason for this cancellation");
        ReserveAuction memory auction = auctionIdToAuction[auctionId];
        require(auction.amount > 0, "NFTMarketReserveAuction: Auction not found");

        delete nftContractToTokenIdToAuctionId[auction.nftContract][auction.tokenId];
        delete auctionIdToAuction[auctionId];

        IERC721Upgradeable(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        if (auction.bidder != address(0)) {
            _sendValueWithFallbackWithdrawWithMediumGasLimit(auction.bidder, auction.amount);
        }

        emit ReserveAuctionCanceledByAdmin(auctionId, reason);
    }

    /**
     * @notice Allows an NFT owner and Foundation to work together in order to update the seller
     * for auctions they have listed to a new account.
     * @param signature Message `I authorize Foundation to migrate my account to ${newAccount.address.toLowerCase()}`
     * signed by the original account.
     * @dev This will gracefully skip any auctions that have already been finalized.
     */
    function adminAccountMigration(
        uint256[] calldata listedAuctionIds,
        address originalAddress,
        address payable newAddress,
        bytes calldata signature
    ) public onlyAuthorizedAccountMigration(originalAddress, newAddress, signature) {
        for (uint256 i = 0; i < listedAuctionIds.length; i++) {
            uint256 auctionId = listedAuctionIds[i];
            ReserveAuction storage auction = auctionIdToAuction[auctionId];
            // The seller would be 0 if it was finalized before this call
            if (auction.seller != address(0)) {
                require(auction.seller == originalAddress, "NFTMarketReserveAuction: Auction not created by that address");
                auction.seller = newAddress;
                emit ReserveAuctionSellerMigrated(auctionId, originalAddress, newAddress);
            }
        }
    }

    uint256[1000] private ______gap;
}