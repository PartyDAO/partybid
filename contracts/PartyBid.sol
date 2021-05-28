// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./interfaces/IMarketWrapper.sol";
import {ERC20} from "./ERC20.sol";
import {ETHOrWETHTransferrer} from "./ETHOrWETHTransferrer.sol";
import {NonReentrant} from "./NonReentrant.sol";
import {ResellerWhitelist} from "./ResellerWhitelist.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 */
contract PartyBid is ERC20, NonReentrant, ETHOrWETHTransferrer {
    // Use OpenZeppelin's SafeMath library to prevent overflows.
    using SafeMath for uint256;

    // ============ Enums ============

    enum AuctionStatus {ACTIVE, WON, LOST, TRANSFERRED}

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyBid pays a 5% fee to PartyDAO
    uint8 internal constant FEE_PERCENT = 5;

    // ============ Public Immutables ============

    address public partyDAOMultisig;
    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // NFT contract
    IERC721Metadata public nftContract;
    // whitelist of approved resellers
    ResellerWhitelist public resellerWhitelist;
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
    // the total spent by PartyBid on the auction;
    // 0 if the NFT is lost; highest bid + 5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // amount of votes for a reseller to pass quorum threshold
    uint256 public supportNeededForQuorum;
    // the ETH balance of the contract from unclaimed contributions
    // decremented each time excess contributions are claimed
    // used to determine the ETH balance of the contract from resale proceeds
    uint256 public excessContributions;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;
    // contributor => voting power (used to support resellers)
    mapping(address => uint256) public votingPower;
    // reseller => total support for reseller
    mapping(address => uint256) public resellerSupport;

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
        uint256 excessContribution,
        uint256 tokenAmount
    );

    event Redeemed(
        address indexed tokenHolder,
        uint256 tokenAmount,
        uint256 redeemAmount
    );

    event ResellerSupported(
        address indexed reseller,
        address indexed supporter,
        uint256 votes,
        uint256 totalVotesForReseller
    );

    event ResellerApproved(address indexed reseller);

    // ======== Receive fallback =========

    receive() external payable {} // solhint-disable-line no-empty-blocks

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _resellerWhitelist,
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _quorumPercent,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        // validate token exists - this call should revert if not
        IERC721Metadata(_nftContract).tokenURI(_tokenId);
        // validate reserve auction exists
        require(
            IMarketWrapper(_marketWrapper).auctionExists(
                _nftContract,
                _tokenId
            ),
            "auction doesn't exist"
        );
        uint256 _auctionId =
            IMarketWrapper(_marketWrapper).getAuctionId(_nftContract, _tokenId);
        // validate quorum percent
        require(0 < _quorumPercent && _quorumPercent <= 100, "!valid quorum");
        // set storage variables
        partyDAOMultisig = _partyDAOMultisig;
        resellerWhitelist = ResellerWhitelist(_resellerWhitelist);
        marketWrapper = IMarketWrapper(_marketWrapper);
        nftContract = IERC721Metadata(_nftContract);
        auctionId = _auctionId;
        tokenId = _tokenId;
        quorumPercent = _quorumPercent;
    }

    // ======== External: Contribute =========

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
        uint256 _currentBalance = address(this).balance.sub(msg.value);
        // add contribution to contributor's array of contributions
        Contribution memory _contribution =
            Contribution({amount: _amount, contractBalance: _currentBalance});
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] = totalContributed[_contributor].add(
            _amount
        );
        // add to party's total contribution
        totalContributedToParty = totalContributedToParty.add(_amount);
        emit Contributed(
            _contributor,
            _amount,
            totalContributed[_contributor],
            _currentBalance
        );
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
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        require(totalContributed[msg.sender] > 0, "only contributors can bid");
        // get the minimum next bid for the auction
        uint256 _auctionMinimumBid = marketWrapper.getMinimumBid(auctionId);
        // ensure there is enough ETH to place the bid including PartyDAO fee
        require(
            _auctionMinimumBid <= _getMaximumBid(),
            "insufficient funds to bid"
        );
        // submit bid to Auction contract using delegatecall
        (bool success, ) =
            address(marketWrapper).delegatecall(
                abi.encodeWithSignature(
                    "bid(uint256,uint256)",
                    auctionId,
                    _auctionMinimumBid
                )
            );
        require(success, "place bid failed");
        // update highest bid submitted & emit success event
        highestBid = _auctionMinimumBid;
        emit Bid(_auctionMinimumBid);
    }

    // ======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external nonReentrant {
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        // finalize auction if it hasn't already been done
        if (!marketWrapper.isFinalized(auctionId)) {
            marketWrapper.finalize(auctionId);
        }
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
            // record total spent by auction & quorum threshold
            totalSpent = highestBid.add(_fee);
            supportNeededForQuorum = totalSpent.mul(quorumPercent).div(100);
            // mint total token supply to PartyBid
            _mint(address(this), valueToTokens(totalSpent));
        }
        // set excess contributions. note: totalSpent is zero if auction was lost
        excessContributions = totalContributedToParty.sub(totalSpent);
        // set the contract status & emit result
        auctionStatus = _result;
        emit Finalized(_result);
    }

    // ======== External: Claim =========

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
        uint256 _excessContribution;
        if (_auctionStatus == AuctionStatus.WON) {
            // calculate the amount of this contributor's ETH
            // that was used for the winning bid
            uint256 _totalUsedForBid = _totalEthUsedForBid(_contributor);
            if (_totalUsedForBid > 0) {
                _tokenAmount = valueToTokens(_totalUsedForBid);
                // transfer tokens to contributor for their portion of ETH used
                _transfer(address(this), _contributor, _tokenAmount);
                // original contributors have fixed power to vote on resellers
                // proportional to the amount of their contributions spent
                votingPower[_contributor] = _totalUsedForBid;
            }
            // return the rest of the contributor's ETH
            _excessContribution = _totalContributed.sub(_totalUsedForBid);
        } else if (_auctionStatus == AuctionStatus.LOST) {
            // return all of the contributor's ETH
            _excessContribution = _totalContributed;
        }
        // if there is excess ETH, send it back to the contributor
        if (_excessContribution > 0) {
            _transferETHOrWETH(_contributor, _excessContribution);
            excessContributions = excessContributions.sub(_excessContribution);
        }
        emit Claimed(
            _contributor,
            _totalContributed,
            _excessContribution,
            _tokenAmount
        );
    }

    // ======== External: SupportReseller =========

    function supportReseller(address _reseller) external nonReentrant {
        require(
            auctionStatus == AuctionStatus.WON,
            "NFT not held; can't resell"
        );
        // ensure the caller has some voting power
        uint256 _votingPower = votingPower[msg.sender];
        require(_votingPower > 0, "no voting power");
        // get the prior votes in support of this reseller
        uint256 _currentSupport = resellerSupport[_reseller];
        // if this is a newly proposed reseller, ensure that they are whitelisted
        bool _isApprovedReseller = _currentSupport > 0;
        require(
            _isApprovedReseller ||
                resellerWhitelist.isWhitelisted(address(this), _reseller),
            "reseller !whitelisted"
        );
        uint256 _updatedSupport = _currentSupport.add(_votingPower);
        // update support for reseller
        resellerSupport[_reseller] = _updatedSupport;
        emit ResellerSupported(
            _reseller,
            msg.sender,
            _votingPower,
            _updatedSupport
        );
        // if this vote hits quorum, transfer the NFT to the reseller
        if (_updatedSupport >= supportNeededForQuorum) {
            IERC721Metadata(nftContract).transferFrom(
                address(this),
                _reseller,
                tokenId
            );
            auctionStatus = AuctionStatus.TRANSFERRED;
            emit ResellerApproved(_reseller);
        }
    }

    // ======== External: Redeem =========

    /**
     * @notice Burn a portion of ERC-20 tokens in exchange for
     * a proportional amount of the redeemable ETH balance of the contract
     * Note: Excess auction contributions must be retrieved via claim()
     * @dev Emits a Redeem event upon success
     * @param _tokenAmount the amount of tokens to burn for ETH
     */
    function redeem(uint256 _tokenAmount) external nonReentrant {
        require(_tokenAmount != 0, "can't redeem zero tokens");
        require(
            balanceOf[msg.sender] >= _tokenAmount,
            "redeem amount exceeds balance"
        );
        uint256 _redeemAmount = redeemAmount(_tokenAmount);
        // prevent users from burning tokens for zero ETH
        require(_redeemAmount > 0, "can't redeem for 0 ETH");
        // burn redeemed tokens
        _burn(msg.sender, _tokenAmount);
        // transfer redeem amount to recipient
        _transferETHOrWETH(msg.sender, _redeemAmount);
        // emit event
        emit Redeemed(msg.sender, _tokenAmount, _redeemAmount);
    }

    // ======== Public: Utility =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 _value)
        public
        pure
        returns (uint256 _tokens)
    {
        _tokens = _value * (TOKEN_SCALE);
    }

    /**
     * @notice The redeemable ETH balance of the contract is equal to
     * any ETH in the contract that is NOT attributed to excess auction contributions
     * e.g. any ETH deposited to the contract EXCEPT via contribute() function
     */
    function redeemableEthBalance()
        public
        view
        returns (uint256 _redeemableBalance)
    {
        _redeemableBalance = address(this).balance.sub(excessContributions);
    }

    /**
     * @notice Helper view function to calculate the ETH amount redeemable
     * in exchange for a given token amount
     */
    function redeemAmount(uint256 _tokenAmount)
        public
        view
        returns (uint256 _redeemAmount)
    {
        // get total redeemable ETH in contract
        uint256 _totalRedeemableBalance = redeemableEthBalance();
        // calculate the proportion of redeemable ETH to be exchanged for this token amount
        _redeemAmount = _totalRedeemableBalance.mul(_tokenAmount).div(
            totalSupply
        );
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
            _total = _total.add(_amount);
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
            _contribution.contractBalance.add(_contribution.amount) <=
            _totalSpent
        ) {
            // contribution was fully used
            _amount = _contribution.amount;
        } else if (_contribution.contractBalance < _totalSpent) {
            // contribution was partially used
            _amount = _totalSpent.sub(_contribution.contractBalance);
        } else {
            // contribution was not used
            _amount = 0;
        }
    }
}
