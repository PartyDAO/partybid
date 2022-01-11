// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {IMarketplaceSettings} from "../superrare/interfaces/IMarketplaceSettings.sol";

interface ISuperRareAuctionHouse {
    /////////////////////////////////////////////////////////////////////////
    // Structs
    /////////////////////////////////////////////////////////////////////////
    // A reserve auction.
    struct Auction {
        bytes32 auctionType;
        uint256 creationBlock;
        address payable auctionCreator;
        uint256 lengthOfAuction;
        uint256 startingBlock;
        uint256 reservePrice;
        uint256 minimumBid;
    }

    // The active bid for a given token, contains the bidder, the marketplace fee at the time of the bid, and the amount of wei placed on the token
    struct ActiveBid {
        address payable bidder;
        uint8 marketplaceFee;
        uint256 amount;
    }

    /////////////////////////////////////////////////////////////////////////
    // minimumBidIncreasePercentage
    /////////////////////////////////////////////////////////////////////////
    function minimumBidIncreasePercentage() external view returns (uint8);

    /////////////////////////////////////////////////////////////////////////
    // iMarketSettings
    /////////////////////////////////////////////////////////////////////////
    function iMarketSettings() external view returns (IMarketplaceSettings);

    /////////////////////////////////////////////////////////////////////////
    // bid
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Bid on artwork with an auction.
     * Rules:
     * - if auction creator is still owner, owner must have contract approved
     * - There must be a running auction or a reserve price auction for the token
     * - bid > 0
     * - if startingBlock - block.number < auctionLengthExtension
     * -    then auctionLength = Starting block - (currentBlock + extension)
     * - Auction creator != bidder
     * - bid >= minimum bid
     * - bid >= reserve price
     * - block.number < startingBlock + lengthOfAuction
     * - bid > current bid
     * - if previous bid then returned
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     * @param _amount uint256 Wei value of the bid.
     */
    function bid(address _contractAddress, uint256 _tokenId, uint256 _amount) 
        external 
        payable;

    /////////////////////////////////////////////////////////////////////////
    // settleAuction
    /////////////////////////////////////////////////////////////////////////
    /**
    * @dev Settles the auction, transferring the auctioned token to the bidder and the bid to auction creator.
    * Rules:
    * - There must be an unsettled auction for the token
    * - current bidder becomes new owner
    * - auction creator gets paid
    * - there is no longer an auction for the token
    * @param _contractAddress address of ERC721 contract.
    * @param _tokenId uint256 id of the token.
    */
    function settleAuction(address _contractAddress, uint256 _tokenId)
        external;

    /////////////////////////////////////////////////////////////////////////
    // getAuctionDetails
    /////////////////////////////////////////////////////////////////////////
    /**
    * @dev Get current auction details for a token
    * Rules:
    * - Return empty when there's no auction
    * @param _contractAddress address of ERC721 contract.
    * @param _tokenId uint256 id of the token.
    */
    function getAuctionDetails(address _contractAddress, uint256 _tokenId)
        external
        view
        returns (Auction memory);

    /////////////////////////////////////////////////////////////////////////
    // getCurrentBid
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Get the current bid
     * Rules:
     * - Return empty when there's no bid
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     */
    function getCurrentBid(address _contractAddress, uint256 _tokenId)
        external
        view
        returns (address, uint256);

    
}