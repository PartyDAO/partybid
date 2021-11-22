// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "@openzeppelin/contracts2/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts2/math/SafeMath.sol";
import "@openzeppelin/contracts2/access/Ownable.sol";
import "./interfaces/IERC721CreatorRoyalty.sol";
import "./interfaces/old/IMarketplaceSettings.sol";
import "./Payments.sol";

import "hardhat/console.sol";

contract SuperRareAuctionHouse is Ownable, Payments {
    using SafeMath for uint256;

    /////////////////////////////////////////////////////////////////////////
    // Constants
    /////////////////////////////////////////////////////////////////////////

    // Types of Auctions
    bytes32 public constant COLDIE_AUCTION = "COLDIE_AUCTION";
    bytes32 public constant SCHEDULED_AUCTION = "SCHEDULED_AUCTION";
    bytes32 public constant NO_AUCTION = bytes32(0);

    /////////////////////////////////////////////////////////////////////////
    // Structs
    /////////////////////////////////////////////////////////////////////////
    // A reserve auction.
    struct Auction {
        address payable auctionCreator;
        uint256 creationBlock;
        uint256 lengthOfAuction;
        uint256 startingBlock;
        uint256 reservePrice;
        uint256 minimumBid;
        bytes32 auctionType;
    }

    // The active bid for a given token, contains the bidder, the marketplace fee at the time of the bid, and the amount of wei placed on the token
    struct ActiveBid {
        address payable bidder;
        uint8 marketplaceFee;
        uint256 amount;
    }

    /////////////////////////////////////////////////////////////////////////
    // State Variables
    /////////////////////////////////////////////////////////////////////////

    // Marketplace Settings Interface
    IMarketplaceSettings public iMarketSettings;

    // Creator Royalty Interface
    IERC721CreatorRoyalty public iERC721CreatorRoyalty;

    // Mapping from ERC721 contract to mapping of tokenId to Auctions.
    mapping(address => mapping(uint256 => Auction)) private auctions;

    // Mapping of ERC721 contract to mapping of token ID to the current bid amount.
    mapping(address => mapping(uint256 => ActiveBid)) private currentBids;

    // Number of blocks to begin refreshing auction lengths
    uint256 public auctionLengthExtension;

    // Max Length that an auction can be
    uint256 public maxLength;

    // A minimum increase in bid amount when out bidding someone.
    uint8 public minimumBidIncreasePercentage; // 10 = 10%
    /////////////////////////////////////////////////////////////////////////
    // Events
    /////////////////////////////////////////////////////////////////////////
    event NewColdieAuction(
        address indexed _contractAddress,
        uint256 indexed _tokenId,
        address indexed _auctionCreator,
        uint256 _reservePrice,
        uint256 _lengthOfAuction
    );

    event CancelAuction(
        address indexed _contractAddress,
        uint256 indexed _tokenId,
        address indexed _auctionCreator
    );

    event NewScheduledAuction(
        address indexed _contractAddress,
        uint256 indexed _tokenId,
        address indexed _auctionCreator,
        uint256 _startingBlock,
        uint256 _minimumBid,
        uint256 _lengthOfAuction
    );

    event AuctionBid(
        address indexed _contractAddress,
        address indexed _bidder,
        uint256 indexed _tokenId,
        uint256 _amount,
        bool _startedAuction,
        uint256 _newAuctionLength,
        address _previousBidder
    );

    event AuctionSettled(
        address indexed _contractAddress,
        address indexed _bidder,
        address _seller,
        uint256 indexed _tokenId,
        uint256 _amount
    );

    /////////////////////////////////////////////////////////////////////////
    // Constructor
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Initializes the contract setting the market settings and creator royalty interfaces.
     * @param _iMarketSettings address to set as iMarketSettings.
     * @param _iERC721CreatorRoyalty address to set as iERC721CreatorRoyalty.
     */
    constructor(address _iMarketSettings, address _iERC721CreatorRoyalty)
    {
        maxLength = 43200; // ~ 7 days == 7 days * 24 hours * 3600s / 14s per block
        auctionLengthExtension = 65; // ~ 15 min == 15 min * 60s / 14s per block

        require(
            _iMarketSettings != address(0),
            "constructor::Cannot have null address for _iMarketSettings"
        );

        require(
            _iERC721CreatorRoyalty != address(0),
            "constructor::Cannot have null address for _iERC721CreatorRoyalty"
        );

        // Set iMarketSettings
        iMarketSettings = IMarketplaceSettings(_iMarketSettings);

        // Set iERC721CreatorRoyalty
        iERC721CreatorRoyalty = IERC721CreatorRoyalty(_iERC721CreatorRoyalty);

        minimumBidIncreasePercentage = 10;
    }

    /////////////////////////////////////////////////////////////////////////
    // setIMarketplaceSettings
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Admin function to set the marketplace settings.
     * Rules:
     * - only owner
     * - _address != address(0)
     * @param _address address of the IMarketplaceSettings.
     */
    function setMarketplaceSettings(address _address) public onlyOwner {
        require(
            _address != address(0),
            "setMarketplaceSettings::Cannot have null address for _iMarketSettings"
        );

        iMarketSettings = IMarketplaceSettings(_address);
    }

    /////////////////////////////////////////////////////////////////////////
    // setIERC721CreatorRoyalty
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Admin function to set the IERC721CreatorRoyalty.
     * Rules:
     * - only owner
     * - _address != address(0)
     * @param _address address of the IERC721CreatorRoyalty.
     */
    function setIERC721CreatorRoyalty(address _address) public onlyOwner {
        require(
            _address != address(0),
            "setIERC721CreatorRoyalty::Cannot have null address for _iERC721CreatorRoyalty"
        );

        iERC721CreatorRoyalty = IERC721CreatorRoyalty(_address);
    }

    /////////////////////////////////////////////////////////////////////////
    // setMaxLength
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Admin function to set the maxLength of an auction.
     * Rules:
     * - only owner
     * - _maxLangth > 0
     * @param _maxLength uint256 max length of an auction.
     */
    function setMaxLength(uint256 _maxLength) public onlyOwner {
        require(
            _maxLength > 0,
            "setMaxLength::_maxLength must be greater than 0"
        );

        maxLength = _maxLength;
    }

    /////////////////////////////////////////////////////////////////////////
    // setMinimumBidIncreasePercentage
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Admin function to set the minimum bid increase percentage.
     * Rules:
     * - only owner
     * @param _percentage uint8 to set as the new percentage.
     */
    function setMinimumBidIncreasePercentage(uint8 _percentage)
        public
        onlyOwner
    {
        minimumBidIncreasePercentage = _percentage;
    }

    /////////////////////////////////////////////////////////////////////////
    // setAuctionLengthExtension
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Admin function to set the auctionLengthExtension of an auction.
     * Rules:
     * - only owner
     * - _auctionLengthExtension > 0
     * @param _auctionLengthExtension uint256 max length of an auction.
     */
    function setAuctionLengthExtension(uint256 _auctionLengthExtension)
        public
        onlyOwner
    {
        require(
            _auctionLengthExtension > 0,
            "setAuctionLengthExtension::_auctionLengthExtension must be greater than 0"
        );

        auctionLengthExtension = _auctionLengthExtension;
    }

    /////////////////////////////////////////////////////////////////////////
    // createColdieAuction
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev create a reserve auction token contract address, token id, price
     * Rules:
     * - Cannot create an auction if contract isn't approved by owner
     * - lengthOfAuction (in blocks) > 0
     * - lengthOfAuction (in blocks) <= maxLength
     * - Reserve price must be >= 0
     * - Must be owner of the token
     * - Cannot have a current auction going
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     * @param _reservePrice uint256 Wei value of the reserve price.
     * @param _lengthOfAuction uint256 length of auction in blocks.
     */
    function createColdieAuction(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _reservePrice,
        uint256 _lengthOfAuction
    ) public {
        // Rules
        _requireOwnerApproval(_contractAddress, _tokenId);
        _requireOwnerAsSender(_contractAddress, _tokenId);
        require(
            _lengthOfAuction <= maxLength,
            "createColdieAuction::Cannot have auction longer than maxLength"
        );
        require(
            auctions[_contractAddress][_tokenId].auctionType == NO_AUCTION ||
                (msg.sender !=
                    auctions[_contractAddress][_tokenId].auctionCreator),
            "createColdieAuction::Cannot have a current auction"
        );
        require(
            _lengthOfAuction > 0,
            "createColdieAuction::_lengthOfAuction must be > 0"
        );
        require(
            _reservePrice >= 0,
            "createColdieAuction::_reservePrice must be >= 0"
        );
        require(
            _reservePrice <= iMarketSettings.getMarketplaceMaxValue(),
            "createColdieAuction::Cannot set reserve price higher than max value"
        );

        // Create the auction
        auctions[_contractAddress][_tokenId] = Auction(
            msg.sender,
            block.number,
            _lengthOfAuction,
            0,
            _reservePrice,
            0,
            COLDIE_AUCTION
        );

        emit NewColdieAuction(
            _contractAddress,
            _tokenId,
            msg.sender,
            _reservePrice,
            _lengthOfAuction
        );
    }

    /////////////////////////////////////////////////////////////////////////
    // cancelAuction
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev cancel an auction
     * Rules:
     * - Must have an auction for the token
     * - Auction cannot have started
     * - Must be the creator of the auction
     * - Must return token to owner if escrowed
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     */
    function cancelAuction(address _contractAddress, uint256 _tokenId)
        external
    {
        require(
            auctions[_contractAddress][_tokenId].auctionType != NO_AUCTION,
            "cancelAuction::Must have a current auction"
        );
        require(
            auctions[_contractAddress][_tokenId].startingBlock == 0 ||
                auctions[_contractAddress][_tokenId].startingBlock >
                block.number,
            "cancelAuction::auction cannot be started"
        );
        require(
            auctions[_contractAddress][_tokenId].auctionCreator == msg.sender,
            "cancelAuction::must be the creator of the auction"
        );

        Auction memory auction = auctions[_contractAddress][_tokenId];

        auctions[_contractAddress][_tokenId] = Auction(
            address(0),
            0,
            0,
            0,
            0,
            0,
            NO_AUCTION
        );

        // Return the token if this contract escrowed it
        IERC721 erc721 = IERC721(_contractAddress);
        if (erc721.ownerOf(_tokenId) == address(this)) {
            erc721.transferFrom(address(this), msg.sender, _tokenId);
        }

        emit CancelAuction(_contractAddress, _tokenId, auction.auctionCreator);
    }

    /////////////////////////////////////////////////////////////////////////
    // createScheduledAuction
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev create a scheduled auction token contract address, token id
     * Rules:
     * - lengthOfAuction (in blocks) > 0
     * - startingBlock > currentBlock
     * - Cannot create an auction if contract isn't approved by owner
     * - Minimum bid must be >= 0
     * - Must be owner of the token
     * - Cannot have a current auction going for this token
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     * @param _minimumBid uint256 Wei value of the reserve price.
     * @param _lengthOfAuction uint256 length of auction in blocks.
     * @param _startingBlock uint256 block number to start the auction on.
     */
    function createScheduledAuction(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _minimumBid,
        uint256 _lengthOfAuction,
        uint256 _startingBlock
    ) external {
        require(
            _lengthOfAuction > 0,
            "createScheduledAuction::_lengthOfAuction must be greater than 0"
        );
        require(
            _lengthOfAuction <= maxLength,
            "createScheduledAuction::Cannot have auction longer than maxLength"
        );
        require(
            _startingBlock > block.number,
            "createScheduledAuction::_startingBlock must be greater than block.number"
        );
        require(
            _minimumBid <= iMarketSettings.getMarketplaceMaxValue(),
            "createScheduledAuction::Cannot set minimum bid higher than max value"
        );
        _requireOwnerApproval(_contractAddress, _tokenId);
        _requireOwnerAsSender(_contractAddress, _tokenId);
        require(
            auctions[_contractAddress][_tokenId].auctionType == NO_AUCTION ||
                (msg.sender !=
                    auctions[_contractAddress][_tokenId].auctionCreator),
            "createScheduledAuction::Cannot have a current auction"
        );

        // Create the scheduled auction.
        auctions[_contractAddress][_tokenId] = Auction(
            msg.sender,
            block.number,
            _lengthOfAuction,
            _startingBlock,
            0,
            _minimumBid,
            SCHEDULED_AUCTION
        );

        // Transfer the token to this contract to act as escrow.
        IERC721 erc721 = IERC721(_contractAddress);
        erc721.transferFrom(msg.sender, address(this), _tokenId);

        emit NewScheduledAuction(
            _contractAddress,
            _tokenId,
            msg.sender,
            _startingBlock,
            _minimumBid,
            _lengthOfAuction
        );
    }

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
    function bid(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external payable {
        Auction memory auction = auctions[_contractAddress][_tokenId];

        // Must have existing auction.
        require(
            auction.auctionType != NO_AUCTION,
            "bid::Must have existing auction"
        );

        // Must have existing auction.
        require(
            auction.auctionCreator != msg.sender,
            "bid::Cannot bid on your own auction"
        );

        // Must have pending coldie auction or running auction.
        require(
            auction.startingBlock <= block.number,
            "bid::Must have a running auction or pending coldie auction"
        );

        // Check that bid is greater than 0.
        require(_amount > 0, "bid::Cannot bid 0 Wei.");

        // Check that bid is less than max value.
        require(
            _amount <= iMarketSettings.getMarketplaceMaxValue(),
            "bid::Cannot bid higher than max value"
        );

        // Check that bid is larger than min value.
        require(
            _amount >= iMarketSettings.getMarketplaceMinValue(),
            "bid::Cannot bid lower than min value"
        );

        // Check that bid is larger than minimum bid value or the reserve price.
        require(
            (_amount >= auction.reservePrice && auction.minimumBid == 0) ||
                (_amount >= auction.minimumBid && auction.reservePrice == 0),
            "bid::Cannot bid lower than reserve or minimum bid"
        );

        // Auction cannot have ended.
        require(
            auction.startingBlock == 0 ||
                block.number <
                auction.startingBlock.add(auction.lengthOfAuction),
            "bid::Cannot have ended"
        );

        // Check that enough ether was sent.
        uint256 requiredCost =
            _amount.add(iMarketSettings.calculateMarketplaceFee(_amount));
        require(requiredCost == msg.value, "bid::Must bid the correct amount.");

        // If owner of token is auction creator make sure they have contract approved
        IERC721 erc721 = IERC721(_contractAddress);
        address owner = erc721.ownerOf(_tokenId);

        // Check that token is owned by creator or by this contract
        require(
            auction.auctionCreator == owner || owner == address(this),
            "bid::Cannot bid on auction if auction creator is no longer owner."
        );

        if (auction.auctionCreator == owner) {
            _requireOwnerApproval(_contractAddress, _tokenId);
        }

        ActiveBid memory currentBid = currentBids[_contractAddress][_tokenId];

        // Must bid higher than current bid.
        require(
            _amount > currentBid.amount &&
                _amount >=
                currentBid.amount.add(
                    currentBid.amount.mul(minimumBidIncreasePercentage).div(100)
                ),
            "bid::must bid higher than previous bid + minimum percentage increase."
        );

        // Return previous bid
        // We do this here because it clears the bid for the refund. This makes it safe from reentrence.
        if (currentBid.amount != 0) {
            _refundBid(_contractAddress, _tokenId);
        }

        // Set the new bid
        currentBids[_contractAddress][_tokenId] = ActiveBid(
            msg.sender,
            iMarketSettings.getMarketplaceFeePercentage(),
            _amount
        );

        // If is a pending coldie auction, start the auction
        if (auction.startingBlock == 0) {
            auctions[_contractAddress][_tokenId].startingBlock = block.number;
            erc721.transferFrom(
                auction.auctionCreator,
                address(this),
                _tokenId
            );
            emit AuctionBid(
                _contractAddress,
                msg.sender,
                _tokenId,
                _amount,
                true,
                0,
                currentBid.bidder
            );
        }
        // If the time left for the auction is less than the extension limit bump the length of the auction.
        else if (
            (auction.startingBlock.add(auction.lengthOfAuction)).sub(
                block.number
            ) < auctionLengthExtension
        ) {
            auctions[_contractAddress][_tokenId].lengthOfAuction = (
                block.number.add(auctionLengthExtension)
            )
                .sub(auction.startingBlock);
            emit AuctionBid(
                _contractAddress,
                msg.sender,
                _tokenId,
                _amount,
                false,
                auctions[_contractAddress][_tokenId].lengthOfAuction,
                currentBid.bidder
            );
        }
        // Otherwise, it's a normal bid
        else {
            emit AuctionBid(
                _contractAddress,
                msg.sender,
                _tokenId,
                _amount,
                false,
                0,
                currentBid.bidder
            );
        }
    }

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
        external
    {
        Auction memory auction = auctions[_contractAddress][_tokenId];

        require(
            auction.auctionType != NO_AUCTION && auction.startingBlock != 0,
            "settleAuction::Must have a current auction that has started"
        );
        require(
            block.number >= auction.startingBlock.add(auction.lengthOfAuction),
            "settleAuction::Can only settle ended auctions."
        );

        ActiveBid memory currentBid = currentBids[_contractAddress][_tokenId];

        currentBids[_contractAddress][_tokenId] = ActiveBid(address(0), 0, 0);
        auctions[_contractAddress][_tokenId] = Auction(
            address(0),
            0,
            0,
            0,
            0,
            0,
            NO_AUCTION
        );
        IERC721 erc721 = IERC721(_contractAddress);

        // If there were no bids then end the auction and return the token to its original owner.
        if (currentBid.bidder == address(0)) {
            // Transfer the token to back to original owner.
            erc721.transferFrom(
                address(this),
                auction.auctionCreator,
                _tokenId
            );
            emit AuctionSettled(
                _contractAddress,
                address(0),
                auction.auctionCreator,
                _tokenId,
                0
            );
            return;
        }

        // Transfer the token to the winner of the auction.
        erc721.transferFrom(address(this), currentBid.bidder, _tokenId);

        address payable owner = _makePayable(owner());
        Payments.payout(
            currentBid.amount,
            !iMarketSettings.hasERC721TokenSold(_contractAddress, _tokenId),
            currentBid.marketplaceFee,
            iERC721CreatorRoyalty.getERC721TokenRoyaltyPercentage(
                _contractAddress,
                _tokenId
            ),
            iMarketSettings.getERC721ContractPrimarySaleFeePercentage(
                _contractAddress
            ),
            auction.auctionCreator,
            owner,
            iERC721CreatorRoyalty.tokenCreator(_contractAddress, _tokenId),
            owner
        );
        iMarketSettings.markERC721Token(_contractAddress, _tokenId, true);
        emit AuctionSettled(
            _contractAddress,
            currentBid.bidder,
            auction.auctionCreator,
            _tokenId,
            currentBid.amount
        );
    }

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
        returns (
            bytes32,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Auction memory auction = auctions[_contractAddress][_tokenId];

        return (
            auction.auctionType,
            auction.creationBlock,
            auction.auctionCreator,
            auction.lengthOfAuction,
            auction.startingBlock,
            auction.minimumBid,
            auction.reservePrice
        );
    }

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
        returns (address, uint256)
    {
        return (
            currentBids[_contractAddress][_tokenId].bidder,
            currentBids[_contractAddress][_tokenId].amount
        );
    }

    /////////////////////////////////////////////////////////////////////////
    // _requireOwnerApproval
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Require that the owner have the SuperRareAuctionHouse approved.
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     */
    function _requireOwnerApproval(address _contractAddress, uint256 _tokenId)
        internal
        view
    {
        IERC721 erc721 = IERC721(_contractAddress);
        address owner = erc721.ownerOf(_tokenId);
        require(
            erc721.isApprovedForAll(owner, address(this)),
            "owner must have approved contract"
        );
    }

    /////////////////////////////////////////////////////////////////////////
    // _requireOwnerAsSender
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Require that the owner be the sender.
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uint256 id of the token.
     */
    function _requireOwnerAsSender(address _contractAddress, uint256 _tokenId)
        internal
        view
    {
        IERC721 erc721 = IERC721(_contractAddress);
        address owner = erc721.ownerOf(_tokenId);
        require(owner == msg.sender, "owner must be message sender");
    }

    /////////////////////////////////////////////////////////////////////////
    // _refundBid
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Internal function to return an existing bid on a token to the
     *      bidder and reset bid.
     * @param _contractAddress address of ERC721 contract.
     * @param _tokenId uin256 id of the token.
     */
    function _refundBid(address _contractAddress, uint256 _tokenId) internal {
        ActiveBid memory currentBid = currentBids[_contractAddress][_tokenId];
        if (currentBid.bidder == address(0)) {
            return;
        }

        currentBids[_contractAddress][_tokenId] = ActiveBid(address(0), 0, 0);

        // refund the bidder
        Payments.refund(
            currentBid.marketplaceFee,
            currentBid.bidder,
            currentBid.amount
        );
    }

    /////////////////////////////////////////////////////////////////////////
    // _makePayable
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Internal function to set a bid.
     * @param _address non-payable address
     * @return payable address
     */
    function _makePayable(address _address)
        internal
        pure
        returns (address payable)
    {
        return address(uint160(_address));
    }
}