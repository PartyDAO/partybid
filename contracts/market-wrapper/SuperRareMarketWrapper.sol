// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports ============
import {ISuperRareAuctionHouse} from "../external/interfaces/ISuperRareAuctionHouse.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";

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

    // ============ Structs ============
    struct Token {
        address contractAddress,
        uint256 tokenId
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
    uint256 public nextAuctionId = 1;

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
    ) external view returns (bool)
    {
        ISuperRareAuctionHouse.Auction memory auction = 
            auctionHouse.getAuctionDetails(_contractAddress, _tokenId);

        require(
            auction.auctionType != NO_AUCTION,
            "bid::Must have existing auction"
        );

        require(
            auction.startingBlock <= block.number,
            "bid::Must have a running auction or pending coldie auction"
        );

        auctionIdToToken[nextAuctionId] = Token(_contractAddress, _tokenId);
        tokenToAuctionId[_contractAddress][_tokenId] = nextAuctionId;

        nextAuctionId++;

        return true;
    }

    /**
     * @notice Calculate the minimum next bid for this auction
     * @return minimum bid amount
     */
    function getMinimumBid(uint256 _auctionId) 
        external 
        view 
        returns (uint256) 
    {
        Token token = auctionIdToToken[_auctionId];

        reqiure(token.tokenId != 0, "getMinimumBid::Auction doesnt exist for given auctionId");

        (_, uint256 currentBid) = auctionHouse.getCurrentBidAmount(
            token.contractAddress, 
            token.tokenId
        );
        uint256 minBidIncrease = auctionHouse.minimumBidIncreasePercentage;

        uint256 amount = currentBid.add(
            currentBid.mul(minBidIncrease)
                .div(100)
        );

        return amount.add(
            auctionHouse.iMarketSettings.calculateMarketplaceFee(currentBid)
        );
    }

    /**
     * @notice Query the current highest bidder for this auction
     * @return highest bidder
     */
    function getCurrentHighestBidder(uint256 auctionId)
        external
        view
        returns (address) 
    {
        Token token = auctionIdToToken[_auctionId];

        reqiure(token.tokenId != 0, "getCurrentHighestBidder::Auction doesnt exist for given auctionId");

        (address highestBidder, _) = auctionHouse.getCurrentBidAmount(token.contractAddress, tokenId);

        return highestBidder;
    }

    /**
     * @notice Submit bid to Market contract
     */
    function bid(uint256 auctionId, uint256 bidAmount) external {
        Token token = auctionIdToToken[_auctionId];

        (bool success, bytes memory returnData) = 
            address(auctionHouse).call{ value: bidAmount }(
                abi.encodeWithSignature(
                    "bid(address,uint256,uint256)", 
                    token.contractAddress,
                    token.tokenId,
                    bidAmount
                )
            );
        require(success, string(returnData));
    }

    /**
     * @notice Determine whether the auction has been finalized
     * @return TRUE if the auction has been finalized
     */
    function isFinalized(uint256 auctionId) external view returns (bool) {
        Token token = auctionIdToToken[_auctionId];
        ISuperRareAuctionHouse.Auction memory auction = 
            auctionHouse.getAuctionDetails(_contractAddress, _tokenId);

        return auction.auctionType == NO_AUCTION;
    }

    /**
     * @notice Finalize the results of the auction
     */
    function finalize(uint256 auctionId) external {
        Token token = auctionIdToToken[_auctionId];
        ISuperRareAuctionHouse.Auction memory auction = 
            auctionHouse.getAuctionDetails(_contractAddress, _tokenId);
        
        require(auction.auctionType != NO_AUCTION, "finalize::cant finalize auction that doesnt exist");
        require(auction.startingBlock > 0, "finalize::cant finalize auction that hasnt started");
        require(block.number > auction.startingBlock.add(auction.lengthOfAuction), "finalize::cant finalize currently running auction");

        auctionHouse.settleAuction(token.contractAddress, token.tokenId);
    }
}
