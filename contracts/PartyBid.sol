/*

      ___           ___           ___           ___           ___           ___                       ___
     /\  \         /\  \         /\  \         /\  \         |\__\         /\  \          ___        /\  \
    /::\  \       /::\  \       /::\  \        \:\  \        |:|  |       /::\  \        /\  \      /::\  \
   /:/\:\  \     /:/\:\  \     /:/\:\  \        \:\  \       |:|  |      /:/\:\  \       \:\  \    /:/\:\  \
  /::\~\:\  \   /::\~\:\  \   /::\~\:\  \       /::\  \      |:|__|__   /::\~\:\__\      /::\__\  /:/  \:\__\
 /:/\:\ \:\__\ /:/\:\ \:\__\ /:/\:\ \:\__\     /:/\:\__\     /::::\__\ /:/\:\ \:|__|  __/:/\/__/ /:/__/ \:|__|
 \/__\:\/:/  / \/__\:\/:/  / \/_|::\/:/  /    /:/  \/__/    /:/~~/~    \:\~\:\/:/  / /\/:/  /    \:\  \ /:/  /
      \::/  /       \::/  /     |:|::/  /    /:/  /        /:/  /       \:\ \::/  /  \::/__/      \:\  /:/  /
       \/__/        /:/  /      |:|\/__/     \/__/         \/__/         \:\/:/  /    \:\__\       \:\/:/  /
                   /:/  /       |:|  |                                    \::/__/      \/__/        \::/__/
                   \/__/         \|__|                                     ~~                        ~~

Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ Internal Imports ============
import {Party} from "./Party.sol";
import {IMarketWrapper} from "./market-wrapper/IMarketWrapper.sol";
import {Structs} from "./Structs.sol";

contract PartyBid is Party {
    // partyStatus Transitions:
    //   (1) PartyStatus.ACTIVE on deploy
    //   (2) PartyStatus.WON or PartyStatus.LOST on finalize()

    enum ExpireCapability {
        CanExpire, // The party can be expired
        BeforeExpiration, // The expiration date is in the future
        PartyOver, // The party is inactive, either won, or lost.
        CurrentlyWinning // The party is currently winning its auction
    }

    // ============ Internal Constants ============

    // PartyBid version 3
    uint16 public constant VERSION = 3;

    // ============ Public Not-Mutated Storage ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // ID of auction within market contract
    uint256 public auctionId;
    // the timestamp at which the Party can be expired.
    // This is mainly to prevent a party from collecting contributions
    // but never reaching the reserve price and having contributions
    // locked up indefinitely.  The party can still continue past
    // this time, but if someone calls `expire()` it will move to
    // the LOST state.
    uint256 public expiresAt;

    // ============ Public Mutable Storage ============

    // the highest bid submitted by PartyBid
    uint256 public highestBid;

    // ============ Events ============

    event Bid(uint256 amount);

    // @notice emitted when a party is won, lost, or expires.
    // @param result The `WON` or `LOST` final party state.
    // @param totalSpent The amount of eth actually spent, including the price of the NFT and the fee.
    // @param fee The eth fee paid to PartyDAO.
    // @param totalContributed Total eth deposited by all contributors, including eth not used in purchase.
    // @param expired True if the party expired before reaching a reserve / placing a bid.
    event Finalized(
        PartyStatus result,
        uint256 totalSpent,
        uint256 fee,
        uint256 totalContributed,
        bool expired
    );

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) Party(_partyDAOMultisig, _tokenVaultFactory, _weth) {}

    // ======== Initializer =========

    function initialize(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol,
        uint256 _durationInSeconds
    ) external initializer {
        // validate auction exists
        require(
            IMarketWrapper(_marketWrapper).auctionIdMatchesToken(
                _auctionId,
                _nftContract,
                _tokenId
            ),
            "PartyBid::initialize: auctionId doesn't match token"
        );
        // initialize & validate shared Party variables
        __Party_init(_nftContract, _split, _tokenGate, _name, _symbol);
        // verify token exists
        tokenId = _tokenId;
        require(
            _getOwner() != address(0),
            "PartyBid::initialize: NFT getOwner failed"
        );
        // set PartyBid-specific state variables
        marketWrapper = IMarketWrapper(_marketWrapper);
        auctionId = _auctionId;
        expiresAt = block.timestamp + _durationInSeconds;
    }

    // ======== External: Contribute =========

    /**
     * @notice Contribute to the Party's treasury
     * while the Party is still active
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute() external payable nonReentrant {
        _contribute();
    }

    // ======== External: Bid =========

    /**
     * @notice Submit a bid to the Market
     * @dev Reverts if insufficient funds to place the bid and pay PartyDAO fees,
     * or if any external auction checks fail (including if PartyBid is current high bidder)
     * Emits a Bid event upon success.
     * Callable by any contributor
     */
    function bid() external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBid::bid: auction not active"
        );
        require(
            totalContributed[msg.sender] > 0,
            "PartyBid::bid: only contributors can bid"
        );
        require(
            address(this) != marketWrapper.getCurrentHighestBidder(auctionId),
            "PartyBid::bid: already highest bidder"
        );
        require(
            !marketWrapper.isFinalized(auctionId),
            "PartyBid::bid: auction already finalized"
        );
        // get the minimum next bid for the auction
        uint256 _bid = marketWrapper.getMinimumBid(auctionId);
        // ensure there is enough ETH to place the bid including PartyDAO fee
        require(
            _bid <= getMaximumBid(),
            "PartyBid::bid: insufficient funds to bid"
        );
        // submit bid to Auction contract using delegatecall
        (bool success, bytes memory returnData) = address(marketWrapper)
            .delegatecall(
                abi.encodeWithSignature("bid(uint256,uint256)", auctionId, _bid)
            );
        require(
            success,
            string(
                abi.encodePacked(
                    "PartyBid::bid: place bid failed: ",
                    returnData
                )
            )
        );
        // update highest bid submitted & emit success event
        highestBid = _bid;
        emit Bid(_bid);
    }

    // ======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBid::finalize: auction not active"
        );
        // finalize auction if it hasn't already been done
        if (!marketWrapper.isFinalized(auctionId)) {
            marketWrapper.finalize(auctionId);
        }
        // after the auction has been finalized,
        // if the NFT is owned by the PartyBid, then the PartyBid won the auction
        address _owner = _getOwner();
        partyStatus = _owner == address(this)
            ? PartyStatus.WON
            : PartyStatus.LOST;
        uint256 _ethFee;
        // if the auction was won,
        if (partyStatus == PartyStatus.WON) {
            // record totalSpent,
            // send ETH fees to PartyDAO,
            // fractionalize the Token
            // send Token fees to PartyDAO & split proceeds to split recipient
            _ethFee = _closeSuccessfulParty(highestBid);
        }
        // set the contract status & emit result
        emit Finalized(
            partyStatus,
            totalSpent,
            _ethFee,
            totalContributedToParty,
            false
        );
    }

    // ======== External: Expire =========

    /**
     * @notice Determines whether a party can be expired. Any status other than `CanExpire` will
     * fail the `expire()` call.
     */
    function canExpire() public view returns (ExpireCapability) {
        if (partyStatus != PartyStatus.ACTIVE) {
            return ExpireCapability.PartyOver;
        }
        // In case there's some variation in how contracts define a "high bid"
        // we fall back to making sure none of the eth contributed is outstanding.
        // If we ever add any features that can send eth for any other purpose we
        // will revisit/remove this.
        if (
            address(this) == marketWrapper.getCurrentHighestBidder(auctionId) ||
            address(this).balance < totalContributedToParty
        ) {
            return ExpireCapability.CurrentlyWinning;
        }
        if (block.timestamp < expiresAt) {
            return ExpireCapability.BeforeExpiration;
        }

        return ExpireCapability.CanExpire;
    }

    function errorStringForCapability(ExpireCapability capability)
        internal
        pure
        returns (string memory)
    {
        if (capability == ExpireCapability.PartyOver)
            return "PartyBid::expire: auction not active";
        if (capability == ExpireCapability.CurrentlyWinning)
            return "PartyBid::expire: currently highest bidder";
        if (capability == ExpireCapability.BeforeExpiration)
            return "PartyBid::expire: expiration time in future";
        return "";
    }

    /**
     * @notice Expires an auction, moving it to LOST state and ending the ability to contribute.
     * @dev Emits a Finalized event upon success; callable by anyone once the expiration date passes.
     */
    function expire() external nonReentrant {
        ExpireCapability expireCapability = canExpire();
        require(
            expireCapability == ExpireCapability.CanExpire,
            errorStringForCapability(expireCapability)
        );
        partyStatus = PartyStatus.LOST;
        emit Finalized(partyStatus, 0, 0, totalContributedToParty, true);
    }

    // ======== Public: Utility Calculations =========

    /**
     * @notice The maximum bid that can be submitted
     * while paying the ETH fee to PartyDAO
     * @return _maxBid the maximum bid
     */
    function getMaximumBid() public view returns (uint256 _maxBid) {
        _maxBid = getMaximumSpend();
    }
}
