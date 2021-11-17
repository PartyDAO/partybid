// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports ============
import {ISuperRareAuctionHouse} from "../external/interfaces/ISuperRareAuctionHouse.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./IMarketWrapper.sol";

/**
 * @title SuperRareMarketWrapper
 * @author Zach Kolodny
 * @notice MarketWrapper contract implementing IMarketWrapper interface
 * according to the logic of SuperRare's NFT Auction House
 * Original SuperRare NFT AuctionHouse code: https://github.com/pixura/pixura-contracts/blob/master/contracts/src/SuperRareAuctionHouse.sol
 */
contract SuperRareMarketWrapper is IMarketWrapper {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // ============ Types of Auctions ============
    bytes32 public constant COLDIE_AUCTION = "COLDIE_AUCTION";
    bytes32 public constant SCHEDULED_AUCTION = "SCHEDULED_AUCTION";
    bytes32 public constant NO_AUCTION = bytes32(0);

    // ============ Structs ============
    struct Token {
        address contractAddress;
        uint256 tokenId;
    }

    // ============ Internal Immutables ============
    ISuperRareAuctionHouse internal immutable auctionHouse;

    // ============ Public Variables ============
    uint256 public auctionIdTracker;
    mapping(uint256 => Token) public auctionIdToToken;
    mapping(address => mapping(uint256 => uint256)) public tokenToAuctionId;

    // ======== Constructor =========
    constructor(address _superRareAuctionHouse) {
        auctionHouse = ISuperRareAuctionHouse(_superRareAuctionHouse);
    }

    // ============ Public Mutable Storage ============
    Counters.Counter public auctionIdCounter;

    // ======== External Functions =========

    /// @notice Registers an auction for a given contract/tokenId if a pending/running auction exists
    /// @param _contractAddress Address of the asset being auctioned.
    /// @param _tokenId Token Id of the asset being auctioned.
    function registerAuction(address _contractAddress, uint256 _tokenId)
        external
    {
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(_contractAddress, _tokenId);

        IERC721 erc721 = IERC721(_contractAddress);

        require(
            auction.auctionType != NO_AUCTION,
            "Must have existing auction"
        );

        require(
            auction.startingBlock <= block.number &&
                (auction.startingBlock == 0 ||
                    block.number <
                    auction.startingBlock.add(auction.lengthOfAuction)),
            "Must have active auction"
        );

        address nftOwner = erc721.ownerOf(_tokenId);

        require(
            nftOwner == auction.auctionCreator,
            "Auction Creator Not Owner"
        );

        auctionIdToToken[auctionIdCounter.current()] = Token(
            _contractAddress,
            _tokenId
        );
        tokenToAuctionId[_contractAddress][_tokenId] = auctionIdCounter
            .current();

        auctionIdCounter.increment();
    }

    /**
     * @notice Determines whether an auction exists/is not finished
     * since SuperRare doesn't use auctionIds
     * @return TRUE if the auctionId matches the tokenId + nftContract
     */
    function auctionIdMatchesToken(
        uint256 _auctionId,
        address _contractAddress,
        uint256 _tokenId
    ) external view override returns (bool) {
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(_contractAddress, _tokenId);

        IERC721 erc721 = IERC721(_contractAddress);

        require(
            auction.auctionType != NO_AUCTION,
            "bid::Must have existing auction"
        );

        require(
            auction.startingBlock <= block.number,
            "bid::Must have active auction"
        );

        address nftOwner = erc721.ownerOf(_tokenId);

        require(
            nftOwner == auction.auctionCreator,
            "Auction Creator Not Owner"
        );

        Token storage token = auctionIdToToken[_auctionId];

        return
            token.contractAddress == _contractAddress &&
            token.tokenId == _tokenId;
    }

    /**
     * @notice Calculate the minimum next bid for this auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 _auctionId)
        external
        view
        override
        returns (uint256)
    {
        Token memory token = auctionIdToToken[_auctionId];

        require(token.tokenId != 0, "Auction doesnt exist");

        (, uint256 currentBid) = auctionHouse.getCurrentBidAmount(
            token.contractAddress,
            token.tokenId
        );
        uint256 minBidIncrease = auctionHouse.minimumBidIncreasePercentage();

        uint256 amount = currentBid.add(
            currentBid.mul(minBidIncrease).div(100)
        );

        return
            amount.add(
                auctionHouse.iMarketSettings().calculateMarketplaceFee(
                    currentBid
                )
            );
    }

    /**
     * @notice Query the current highest bidder for this auction
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 _auctionId)
        external
        view
        override
        returns (address)
    {
        Token memory token = auctionIdToToken[_auctionId];

        require(token.tokenId != 0, "Auction doesnt exist");

        (address highestBidder, ) = auctionHouse.getCurrentBidAmount(
            token.contractAddress,
            token.tokenId
        );

        return highestBidder;
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 _auctionId, uint256 _bidAmount) external override {
        Token memory token = auctionIdToToken[_auctionId];

        (bool success, bytes memory returnData) = address(auctionHouse).call{
            value: _bidAmount
        }(
            abi.encodeWithSignature(
                "bid(address,uint256,uint256)",
                token.contractAddress,
                token.tokenId,
                _bidAmount
            )
        );
        require(success, string(returnData));
    }

    /**
     * @notice Determine whether the auction has been finalized
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 _auctionId)
        external
        view
        override
        returns (bool)
    {
        Token memory token = auctionIdToToken[_auctionId];
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(token.contractAddress, token.tokenId);

        return auction.auctionType == NO_AUCTION;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 _auctionId) external override {
        Token memory token = auctionIdToToken[_auctionId];
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(token.contractAddress, token.tokenId);

        require(
            auction.auctionType != NO_AUCTION,
            "finalize::auction doesnt exist"
        );
        require(auction.startingBlock > 0, "finalize::auction hasnt started");
        require(
            block.number > auction.startingBlock.add(auction.lengthOfAuction),
            "finalize::auction is running"
        );

        auctionHouse.settleAuction(token.contractAddress, token.tokenId);
    }
}
