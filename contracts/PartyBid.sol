// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

// ============ Internal Imports ============
import {IMarket} from "./interfaces/IMarket.sol";
import {ERC20} from "./ERC20.sol";
import {ETHOrWETHTransferrer} from "./ETHOrWETHTransferrer.sol";
import {NonReentrant} from "./NonReentrant.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 */
contract PartyBid is ERC20, NonReentrant, ETHOrWETHTransferrer {
    // Use OpenZeppelin's SafeMath library to prevent overflows.
    using SafeMath for uint256;

    // ============ Enums ============

    enum AuctionStatus {ACTIVE, WON, LOST}
    enum NFTType {Zora, Foundation}

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyBid pays a 5% fee to PartyDAO
    uint8 internal constant FEE_PERCENT = 5;

    // ============ Public Immutables ============

    address public partyDAOMultisig;
    // market contract auctioning the NFT
    IMarket public market;
    // NFT contract
    IERC721Metadata public nftContract;
    uint256 public auctionId;
    uint256 public tokenId;
    // percent (from 1 - 100) of the total token supply
    // required to vote to successfully execute a sale proposal
    uint256 public quorumPercent;

    // ============ Public Mutable Storage ============

    // state of the contract
    AuctionStatus public auctionStatus;
    // total ETH deposited by all contributors
    uint256 public totalContributedToParty;
    // the highest bid submitted by PartyBid
    uint256 public highestBid;
    // the total spent by PartyBid after the auction;
    // 0 if the NFT is lost; highest bid + 5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // total amount of contributions claimed
    uint256 public totalContributionsClaimed;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        uint256 contractBalance;
    }

    // ============ Events ============

    event Contributed(
        address indexed contributor,
        uint256 amount,
        uint256 totalContribution,
        uint256 contractBalance
    );

    event Bid(uint256 amount);

    event Finalized(AuctionStatus result);

    event Claimed(
        address indexed contributor,
        uint256 totalContributed,
        uint256 excessEth,
        uint256 tokenAmount
    );

    //======== Receive fallback =========

    receive() external payable {} // solhint-disable-line no-empty-blocks

    //======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _market,
        address _nftContract,
        uint256 _tokenId,
        uint256 _quorumPercent,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        // validate token exists - this call should revert if not
        IERC721Metadata(_nftContract).tokenURI(_tokenId);
        // validate FOUNDATION reserve auction exists (TODO: generalize Foundation / Zora)
        uint256 _auctionId =
            IMarket(_market).getReserveAuctionIdFor(_nftContract, _tokenId);
        require(_auctionId != 0, "auction doesn't exist");
        // validate quorum percent
        require(0 < _quorumPercent && _quorumPercent <= 100, "!valid quorum");
        // set storage variables
        partyDAOMultisig = _partyDAOMultisig;
        market = IMarket(_market);
        nftContract = IERC721Metadata(_nftContract);
        auctionId = _auctionId;
        tokenId = _tokenId;
        quorumPercent = _quorumPercent;
    }

    //======== External: Contribute =========

    /**
     * @notice Contribute to the PartyBid's treasury
     * while the auction is still open
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute(address _contributor, uint256 _amount)
        external
        payable
        nonReentrant
    {
        require(auctionStatus == AuctionStatus.ACTIVE, "contributions closed");
        require(_amount == msg.value, "amount != value");
        // get the current contract balance
        uint256 _currentBalance = address(this).balance - msg.value;
        // add contribution to contributor's array of contributions
        Contribution memory _contribution =
            Contribution({amount: _amount, contractBalance: _currentBalance});
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] += _amount;
        // add to party's total contribution
        totalContributedToParty += _amount;
        emit Contributed(
            _contributor,
            _amount,
            totalContributed[_contributor],
            _currentBalance
        );
    }

    //======== External: Bid =========

    /**
     * @notice Submit a bid to the Market
     * @dev Reverts if insufficient funds to place the bid and pay PartyDAO fees,
     * or if any external auction checks fail (including if PartyBid is current high bidder)
     * Emits a Bid event upon success.
     * Callable by any contributor
     */
    function bid() external nonReentrant {
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        require(totalContributed[msg.sender] > 0, "only contributors can bid");
        // Place FOUNDATION bid TODO: generalize Foundation / Zora
        // get the minimum next bid for the auction
        uint256 _auctionMinimumBid = market.getMinBidAmount(auctionId);
        // ensure there is enough ETH to place the bid including PartyDAO fee
        require(
            _auctionMinimumBid <= _getMaximumBid(),
            "insufficient funds to bid"
        );
        // submit bid to Auction contract
        market.placeBid{value: _auctionMinimumBid}(auctionId);
        // update highest bid submitted & emit success event
        highestBid = _auctionMinimumBid;
        emit Bid(_auctionMinimumBid);
    }

    //======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external nonReentrant {
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        // finalize auction if it hasn't already been done
        _finalizeAuctionIfNecessary();
        // after the auction has been finalized,
        // if the NFT is owned by the PartyBid, then the PartyBid won the auction
        AuctionStatus _result =
            nftContract.ownerOf(tokenId) == address(this)
                ? AuctionStatus.WON
                : AuctionStatus.LOST;
        // if the auction was won,
        if (_result == AuctionStatus.WON) {
            // transfer 5% fee to PartyDAO
            uint256 _fee = _getFee(highestBid);
            _transferETHOrWETH(partyDAOMultisig, _fee);
            totalSpent = highestBid.add(_fee);
            // mint total token supply to PartyBid
            _mint(address(this), valueToTokens(totalSpent));
        }
        // set the contract status & emit result
        auctionStatus = _result;
        emit Finalized(_result);
    }

    //======== External: Claim =========

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a single contributor after the auction has ended
     * @dev Emits a Claimed event upon success
     * callable by anyone (doesn't have to be the contributor)
     * @param _contributor the address of the contributor
     */
    function claim(address _contributor) external nonReentrant {
        // load auction status once from storage
        AuctionStatus _auctionStatus = auctionStatus;
        // ensure auction has finalized
        require(
            _auctionStatus != AuctionStatus.ACTIVE,
            "auction not finalized"
        );
        // load amount contributed once from storage
        uint256 _totalContributed = totalContributed[_contributor];
        // ensure contributor submitted some ETH
        require(_totalContributed != 0, "! a contributor");
        uint256 _tokenAmount;
        uint256 _excessEth;
        if (_auctionStatus == AuctionStatus.WON) {
            // calculate the amount of this contributor's ETH
            // that was used for the winning bid
            uint256 _totalUsedForBid = _totalEthUsedForBid(_contributor);
            if (_totalUsedForBid > 0) {
                _tokenAmount = valueToTokens(_totalUsedForBid);
                // transfer tokens to contributor for their portion of ETH used
                _transfer(address(this), _contributor, _tokenAmount);
            }
            // return the rest of the contributor's ETH
            _excessEth = _totalContributed - _totalUsedForBid;
        } else if (_auctionStatus == AuctionStatus.LOST) {
            // return all of the contributor's ETH
            _excessEth = _totalContributed;
        }
        // if there is excess ETH, send it back to the contributor
        if (_excessEth > 0) {
            _transferETHOrWETH(_contributor, _excessEth);
        }
        //increment total amount claimed & emit event
        totalContributionsClaimed += _totalContributed;
        emit Claimed(_contributor, _totalContributed, _excessEth, _tokenAmount);
    }

    // ======== Public: Utility =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 value) public pure returns (uint256 tokens) {
        tokens = value * (TOKEN_SCALE);
    }

    // ============ Internal: Bid ============

    /**
     * @notice The maximum bid that can be submitted
     * while leaving 5% fee for PartyDAO
     * @return _maxBid the maximum bid
     */
    function _getMaximumBid() internal view returns (uint256 _maxBid) {
        uint256 _balance = address(this).balance;
        _maxBid = _balance.sub(_getFee(_balance));
    }

    /**
     * @notice Calculate 5% fee for PartyDAO
     * @return _fee 5% of the given amount
     */
    function _getFee(uint256 _amount) internal pure returns (uint256 _fee) {
        _fee = _amount.mul(FEE_PERCENT).div(100);
    }

    // ============ Internal: Finalize ============

    /**
     * @notice Finalize the auction if it hasn't already been done
     * note: FOUNDATION only right now TODO: generalize Foundation / Zora
     */
    function _finalizeAuctionIfNecessary() internal {
        IMarket.ReserveAuction memory _auction =
            market.getReserveAuction(auctionId);
        // check if the auction has already been finalized
        // by seeing if it has been deleted from the contract
        bool _auctionFinalized = _auction.amount == 0;
        if (!_auctionFinalized) {
            // finalize the auction
            // will revert if auction has not started or still in progress
            market.finalizeReserveAuction(auctionId);
        }
    }

    // ============ Internal: Claim ============

    /**
     * @notice Calculate the total amount of a contributor's funds that were
     * used towards the winning auction bid
     * @param _contributor the address of the contributor
     * @return _total the sum of the contributor's funds that were
     * used towards the winning auction bid
     */
    function _totalEthUsedForBid(address _contributor)
        internal
        view
        returns (uint256 _total)
    {
        // get all of the contributor's contributions
        Contribution[] memory _contributions = contributions[_contributor];
        for (uint256 i = 0; i < _contributions.length; i++) {
            // calculate how much was used from this individual contribution
            uint256 _amount = _ethUsedForBid(_contributions[i]);
            // if we reach a contribution that was not used,
            // no subsequent contributions will have been used either,
            // so we can stop calculating to save some gas
            if (_amount == 0) break;
            _total += _amount;
        }
    }

    /**
     * @notice Calculate the amount that was used towards
     * the winning auction bid from a single Contribution
     * @param _contribution the Contribution struct
     * @return _amount the amount of funds from this contribution
     * that were used towards the winning auction bid
     */
    function _ethUsedForBid(Contribution memory _contribution)
        internal
        view
        returns (uint256 _amount)
    {
        // load total amount spent once from storage
        uint256 _totalSpent = totalSpent;
        if (
            _contribution.contractBalance + _contribution.amount <= _totalSpent
        ) {
            // contribution was fully used
            _amount = _contribution.amount;
        } else if (_contribution.contractBalance < _totalSpent) {
            // contribution was partially used
            _amount = _totalSpent - _contribution.contractBalance;
        } else {
            // contribution was not used
            _amount = 0;
        }
    }
}
