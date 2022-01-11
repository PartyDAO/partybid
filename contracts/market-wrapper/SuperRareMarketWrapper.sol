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

    // ============ Structs ============
    struct Token {
        address contractAddress;
        uint256 tokenId;
    }

    // ============ Internal Immutables ============
    ISuperRareAuctionHouse internal immutable auctionHouse;

    // ============ Public Variables ============
    IMarketWrapper public marketWrapper;
    // ID of auction within market contract
    uint256 public auctionId;

    // ============ Public Mutable Storage ============

    // the highest bid submitted by PartyBid
    uint256 public highestBid;

    mapping(uint256 => Token) public auctionIdToToken;

    // ======== Constructor =========
    constructor(address _superRareAuctionHouse) {
        auctionHouse = ISuperRareAuctionHouse(_superRareAuctionHouse);
    }

    // ======== External Functions =========

    /**
     * @notice Determines whether an auction exists/is not finished
     * since SuperRare doesn't use auctionIds
     * @return TRUE if the auctionId matches the tokenId + nftContract
     */
    function auctionIdMatchesToken(
        uint256 _auctionId,
        address _contractAddress,
        uint256 _tokenId
    ) external override returns (bool) {
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(_contractAddress, _tokenId);

        IERC721 erc721 = IERC721(_contractAddress);

        require(
            auction.auctionType != bytes32(0),
            "auctionIdMatchesToken::Must have existing auction"
        );

        require(
            auction.startingBlock <= block.number &&
                (auction.startingBlock == 0 ||
                    block.number <
                    auction.startingBlock.add(auction.lengthOfAuction)),
            "auctionIdMatchesToken::Must have active auction"
        );

        address nftOwner = erc721.ownerOf(_tokenId);

        require(
            nftOwner == auction.auctionCreator,
            "auctionIdMatchesToken::Auction Creator Not Owner"
        );

        Token memory token = auctionIdToToken[_auctionId];

        require(
            token.tokenId == 0 && token.contractAddress == address(0), 
            "auctionIdMatchesToken::auction id in use"
        );

        auctionIdToToken[_auctionId] = Token(
            _contractAddress,
            _tokenId
        );

        return true;
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

        (, uint256 currentBid) = auctionHouse.getCurrentBid(
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

        (address highestBidder, ) = auctionHouse.getCurrentBid(
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
            abi.encodeWithSelector(
                ISuperRareAuctionHouse.bid.selector,
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

        return auction.auctionType == bytes32(0);
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 _auctionId) external override {
        Token memory token = auctionIdToToken[_auctionId];
        ISuperRareAuctionHouse.Auction memory auction = auctionHouse
            .getAuctionDetails(token.contractAddress, token.tokenId);

        require(
            auction.auctionType != bytes32(0),
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
