
// SPDX-License-Identifier: GPL-3.0

/// @title The Koans auction house.

// LICENSE
// KoansAuctionHouse.sol is a modified version of Nouns's AuctionHouse.sol:
// https://etherscan.io/address/0xf15a943787014461d94da08ad4040f79cd7c124e#code
//
// AuctionHouse.sol source code Copyright Nouns Founders licensed under the GPL-3.0 license.
// With modifications by Koans Founders DAO.

pragma solidity ^0.8.6;

import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IKoansToken } from "./interfaces/IKoansToken.sol";
import { ISashoToken } from "./interfaces/ISashoToken.sol";
import { IKoansAuctionHouse } from "./interfaces/IKoansAuctionHouse.sol";
import { IWETH } from "./interfaces/IWETH.sol";

contract KoansAuctionHouse is IKoansAuctionHouse, Pausable, ReentrancyGuard, Ownable {
    // The Koans ERC721 token contract
    IKoansToken public koans;

    // The Sashos ERC20 token contract.
    ISashoToken public sashos;

    // The address of the WETH contract
    address public weth;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;

    // The minimum price accepted in an auction
    uint256 public reservePrice;

    // The minimum percentage difference between the last bid amount and the current bid
    uint8 public minBidIncrementPercentage;

    // The duration of a single auction
    uint256 public duration;

    // The active auction
    IKoansAuctionHouse.Auction public auction;

    // Vector of offered URIs.
    string[] public offerURIs;

    // Vector of the addresses to payout to for each of the offer URIs.
    address payable[] public offerPayoutAddresses;

    // The index of the next offer to be auctioned off.
    uint256 public nextOfferURIIndex;

    // Address of the Koan Offer contract.
    address public koanOfferAddress;

    // Basis points of the fraction of the auction to be sent to the a
    // payout address of an auction as a reward.
    uint256 public payoutRewardBP;

    // Address of the Koans founder's wallet.
    address public koansFoundersAddress;

    // Basis points of the fraction of the auction to be sent to the 

    /**
     * @notice Initialize the auction house and base contracts,
     * populate configuration values, and pause the contract.
     * @dev This function can only be called once.
     */
    constructor(
        IKoansToken _koans,
        ISashoToken _sashos,
        address _weth,
        uint256 _timeBuffer,
        uint256 _reservePrice,
        uint8 _minBidIncrementPercentage,
        uint256 _duration,
        address _koanOfferAddress,
        address _koansFoundersAddress
    ) {
        _pause();

        koans = _koans;
        sashos = _sashos;
        weth = _weth;
        timeBuffer = _timeBuffer;
        reservePrice = _reservePrice;
        minBidIncrementPercentage = _minBidIncrementPercentage;
        duration = _duration;
        koanOfferAddress = _koanOfferAddress;
        payoutRewardBP = 5000;
        nextOfferURIIndex = 0;
        koansFoundersAddress = _koansFoundersAddress;
    }

    /**
     * @notice Settle the current auction, mint a new Koan, and put it up for auction.
     */
    function settleCurrentAndCreateNewAuction() external override nonReentrant whenNotPaused {
        _settleAuction();
        _createAuction();
    }

    /**
     * @notice Settle the current auction.
     * @dev This function can only be called when the contract is paused.
     */
    function settleAuction() external override whenPaused nonReentrant {
        _settleAuction();
    }

    /**
     * @notice Create a bid for a Koan, with a given amount.
     * @dev This contract only accepts payment in ETH.
     */
    function createBid(uint256 koanId) external payable override nonReentrant {
        IKoansAuctionHouse.Auction memory _auction = auction;

        require(_auction.koanId == koanId, "Koan not up for auction");
        require(block.timestamp < _auction.endTime, "Auction expired");
        require(msg.value >= reservePrice, "Must send at least reservePrice");
        require(
            msg.value >= _auction.amount + ((_auction.amount * minBidIncrementPercentage) / 100),
            "Insufficient bid."
        );

        address payable lastBidder = _auction.bidder;

        // Refund the last bidder, if applicable
        if (lastBidder != address(0)) {
            _safeTransferETHWithFallback(lastBidder, _auction.amount);
        }

        auction.amount = msg.value;
        auction.bidder = payable(msg.sender);

        // Extend the auction if the bid was received within `timeBuffer` of the auction end time
        bool extended = _auction.endTime - block.timestamp < timeBuffer;
        if (extended) {
            auction.endTime = _auction.endTime = block.timestamp + timeBuffer;
        }

        emit AuctionBid(_auction.koanId, msg.sender, msg.value, extended);

        if (extended) {
            emit AuctionExtended(_auction.koanId, _auction.endTime);
        }
    }

    /**
     * @notice Add an offer to the queue of offers to be auctioned.
     */
    function addOffer(string memory _uri, address _payoutAddress) external override nonReentrant {
        require(msg.sender == koanOfferAddress, "Must be Offer contract");
        offerURIs.push(_uri);
        offerPayoutAddresses.push(payable(_payoutAddress));
    }  

    /**
     * @notice Pause the Koans auction house.
     * @dev This function can only be called by the owner when the
     * contract is unpaused. While no new auctions can be started when paused,
     * anyone can settle an ongoing auction.
     */
    function pause() external override onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the Koans auction house.
     * @dev This function can only be called by the owner when the
     * contract is paused. If required, this function will start a new auction.
     */
    function unpause() external override onlyOwner {
        _unpause();

        if (auction.startTime == 0 || auction.settled) {
            _createAuction();
        }
    }

    /**
     * @notice Set the auction time buffer.
     * @dev Only callable by the owner.
     */
    function setTimeBuffer(uint256 _timeBuffer) external override onlyOwner {
        timeBuffer = _timeBuffer;

        emit AuctionTimeBufferUpdated(_timeBuffer);
    }

    /**
     * @notice Set the auction reserve price.
     * @dev Only callable by the owner.
     */
    function setReservePrice(uint256 _reservePrice) external override onlyOwner {
        reservePrice = _reservePrice;

        emit AuctionReservePriceUpdated(_reservePrice);
    }

    /**
     * @notice Set the auction minimum bid increment percentage.
     * @dev Only callable by the owner.
     */
    function setMinBidIncrementPercentage(uint8 _minBidIncrementPercentage) external override onlyOwner {
        minBidIncrementPercentage = _minBidIncrementPercentage;

        emit AuctionMinBidIncrementPercentageUpdated(_minBidIncrementPercentage);
    }

    /**
     * @notice Set the percent of the auction proceeds that are sent to the payout address.
     * @dev Only callable by the owner.
     */
    function setPayoutRewardBP(uint256 _payoutRewardBP) external override onlyOwner {
        require(_payoutRewardBP <= 10000, "BP greater than 10000");
        if (auction.koanId < 100) {
            require(_payoutRewardBP <= 9000, "BP greather than 9000");
        }
        payoutRewardBP = _payoutRewardBP;

        emit PayoutRewardBPUpdated(_payoutRewardBP);
    }

    /**
     * @notice Set the duration of the auction in seconds.
     * @dev Only callable by the owner.
     */
    function setDuration(uint256 _duration) external override onlyOwner {
        duration = _duration;
        
        emit AuctionDurationUpdated(_duration);
    }

    /**
     * @notice Set the address of the offer contract.
     * @dev Only callable by the owner.
     */
    function setOfferAddress(address _koanOfferAddress) external override onlyOwner {
        koanOfferAddress = _koanOfferAddress;
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the `auction` state variable and emit an AuctionCreated event.
     * If the mint reverts, the minter was updated without pausing this contract first. To remedy this,
     * catch the revert and pause this contract.
     */
    function _createAuction() internal {
        require(nextOfferURIIndex < offerURIs.length, "No proposed URIs ready.");
        try koans.mint() returns (uint256 koanId) {
            uint256 startTime = block.timestamp;
            uint256 endTime = startTime + duration;
            koans.setMetadataURI(koanId, offerURIs[nextOfferURIIndex]);
            auction = Auction({
                koanId: koanId,
                amount: 0,
                startTime: startTime,
                endTime: endTime,
                bidder: payable(0),
                settled: false,
                payoutAddress: offerPayoutAddresses[nextOfferURIIndex]
            });

            nextOfferURIIndex += 1;

            emit AuctionCreated(koanId, startTime, endTime);
        } catch Error(string memory) {
            _pause();
        }
    }

    /**
     * @notice Settle an auction, finalizing the bid and paying out to the owner.
     * @dev If there are no bids, the Koan is burned.
     */
    function _settleAuction() internal {
        IKoansAuctionHouse.Auction memory _auction = auction;

        require(_auction.startTime != 0, "Auction hasn't begun");
        require(!_auction.settled, "Auction has already been settled");
        require(block.timestamp >= _auction.endTime, "Auction hasn't completed");

        auction.settled = true;

        if (_auction.bidder == address(0)) {
            koans.burn(_auction.koanId);
        } else {
            koans.transferFrom(address(this), _auction.bidder, _auction.koanId);
        }


        if (_auction.amount > 0) {
            uint256 koansFoundersReward = 0;
            if (auction.koanId < 100) {
                koansFoundersReward = _auction.amount * 1000 / 10000;
                _safeTransferETHWithFallback(koansFoundersAddress, koansFoundersReward);
            }
            uint256 payoutReward = _auction.amount * payoutRewardBP / 10000;
            _safeTransferETHWithFallback(_auction.payoutAddress, payoutReward);
            _safeTransferETHWithFallback(owner(), (_auction.amount - koansFoundersReward) - payoutReward);
        }

        sashos.mint(owner(), 1000000 ether);

        emit AuctionSettled(_auction.koanId, _auction.bidder, _auction.amount);
    }

    /**
     * @notice Transfer ETH. If the ETH transfer fails, wrap the ETH and try send it as WETH.
     */
    function _safeTransferETHWithFallback(address to, uint256 amount) internal {
        if (!_safeTransferETH(to, amount)) {
            IWETH(weth).deposit{ value: amount }();
            IERC20(weth).transfer(to, amount);
        }
    }

    /**
     * @notice Transfer ETH and return the success status.
     * @dev This function only forwards 30,000 gas to the callee.
     */
    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{ value: value, gas: 30_000 }(new bytes(0));
        return success;
    }
}
