pragma solidity ^0.8.5;

interface IKoansAuctionHouse {
    struct Auction {
        // ID for the Koan (ERC721 token ID)
        uint256 koanId;
        // The current highest bid amount
        uint256 amount;
        // The time that the auction started
        uint256 startTime;
        // The time that the auction is scheduled to end
        uint256 endTime;
        // The address of the current highest bid
        address payable bidder;
        // Whether or not the auction has been settled
        bool settled;
        // The address to payout a portion of the auction's proceeds to.
        address payable payoutAddress;
    }

    event AuctionCreated(uint256 indexed koanId, uint256 startTime, uint256 endTime);

    event AuctionBid(uint256 indexed koanId, address sender, uint256 value, bool extended);

    event AuctionExtended(uint256 indexed koanId, uint256 endTime);

    event AuctionSettled(uint256 indexed koanId, address winner, uint256 amount);

    event AuctionTimeBufferUpdated(uint256 timeBuffer);

    event AuctionReservePriceUpdated(uint256 reservePrice);

    event AuctionMinBidIncrementPercentageUpdated(uint256 minBidIncrementPercentage);

    event PayoutRewardBPUpdated(uint256 artistRewardBP);

    event AuctionDurationUpdated(uint256 duration);

    function reservePrice() external view returns (uint256);

    function minBidIncrementPercentage() external view returns (uint8);

    function auction() external view returns (uint256, uint256, uint256, uint256, address payable, bool, address payable);

    function settleCurrentAndCreateNewAuction() external;

    function settleAuction() external;

    function createBid(uint256 koanId) external payable;

    function addOffer(string memory _uri, address _payoutAddress) external;

    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);

    function setTimeBuffer(uint256 _timeBuffer) external;

    function setReservePrice(uint256 _reservePrice) external;

    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external;

    function setPayoutRewardBP(uint256 _payoutRewardBP) external;

    function setDuration(uint256 _duration) external;

    function setOfferAddress(address _koanOfferAddress) external;
}