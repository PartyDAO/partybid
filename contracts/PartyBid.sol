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

PartyBid v3
Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports: Inherited Contracts ============
// NOTE: we inherit from OpenZeppelin upgradeable contracts
// because of the proxy structure used for cheaper deploys
// (the proxies are NOT actually upgradeable)
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    ERC721HolderUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
// ============ External Imports: External Contracts & Contract Interfaces ============
import {
    IERC721VaultFactory
} from "./external/interfaces/IERC721VaultFactory.sol";
import {ITokenVault} from "./external/interfaces/ITokenVault.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./market-wrapper/IMarketWrapper.sol";
import {Party} from "./Party.sol";

contract PartyBid is Party {
    // partyStatus Transitions:
    //   (1) PartyStatus.ACTIVE on deploy
    //   (2) PartyStatus.WON or PartyStatus.LOST on finalize()

    // ============ Internal Constants ============

    // PartyBid version 3
    uint16 public constant VERSION = 3;

    // ============ Public Not-Mutated Storage ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // ID of auction within market contract
    uint256 public auctionId;

    // ============ Public Mutable Storage ============

    // the highest bid submitted by PartyBid
    uint256 public highestBid;

    // ============ Events ============

    event Bid(uint256 amount);

    event Finalized(PartyStatus result, uint256 totalSpent, uint256 fee, uint256 totalContributed);

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
        address _splitRecipient,
        uint256 _splitBasisPoints,
        string memory _name,
        string memory _symbol
    ) external initializer {
        // initialize ReentrancyGuard and ERC721Holder
        __ReentrancyGuard_init();
        __ERC721Holder_init();
        // set storage variables
        marketWrapper = IMarketWrapper(_marketWrapper);
        nftContract = IERC721Metadata(_nftContract);
        tokenId = _tokenId;
        auctionId = _auctionId;
        name = _name;
        symbol = _symbol;
        // validate that party split won't retain the total token supply
        uint256 _remainingBasisPoints = 10000 - TOKEN_FEE_BASIS_POINTS;
        require(_splitBasisPoints < _remainingBasisPoints, "PartyBid::initialize: basis points can't take 100%");
        // validate that a portion of the token supply is not being burned
        if (_splitRecipient == address(0)) {
            require(_splitBasisPoints == 0, "PartyBid::initialize: can't send tokens to burn addr");
        }
        splitBasisPoints = _splitBasisPoints;
        splitRecipient = _splitRecipient;
        // validate token exists
        require(_getOwner() != address(0), "PartyBid::initialize: NFT getOwner failed");
        // validate auction exists
        require(
            marketWrapper.auctionIdMatchesToken(
                _auctionId,
                _nftContract,
                _tokenId
            ),
            "PartyBid::initialize: auctionId doesn't match token"
        );
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
            address(this) !=
                marketWrapper.getCurrentHighestBidder(
                    auctionId
                ),
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
        (bool success, bytes memory returnData) =
            address(marketWrapper).delegatecall(
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
        partyStatus = _owner == address(this) ? PartyStatus.WON : PartyStatus.LOST;
        uint256 _ethFee;
        // if the auction was won,
        if (partyStatus == PartyStatus.WON) {
            // calculate PartyDAO fee & record total spent
            _ethFee = _getEthFee(highestBid);
            totalSpent = highestBid + _ethFee;
            // transfer ETH fee to PartyDAO
            _transferETHOrWETH(partyDAOMultisig, _ethFee);
            // deploy fractionalized NFT vault
            // and mint fractional ERC-20 tokens
            _fractionalizeNFT(highestBid);
        }
        // set the contract status & emit result
        emit Finalized(partyStatus, totalSpent, _ethFee, totalContributedToParty);
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
