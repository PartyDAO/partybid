// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ Internal Imports ============
import {IERC721} from "./interfaces/IERC721.sol";
import {ERC20} from "./ERC20.sol";
import {ETHOrWETHTransferrer} from "./ETHOrWETHTransferrer.sol";
import "./NonReentrant.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 */
contract PartyBid is ERC20, NonReentrant, ETHOrWETHTransferrer {
    // ============ Enums ============

    enum AuctionStatus {ACTIVE, WON, LOST}
    enum NFTType {Zora, Foundation}

    // ============ Internal Constants ============

    uint16 internal constant TOKEN_SCALE = 1000;
    // TODO: triple check addresses
    address internal constant ZORA_NFT_CONTRACT =
        address(0xabEFBc9fD2F806065b4f3C237d4b59D9A97Bcac7);
    address internal constant FOUNDATION_NFT_CONTRACT =
        address(0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405);

    // ============ Public Immutables ============

    address public nftContract;
    uint256 public tokenId;
    uint256 public quorumPercent;

    // ============ Public Mutable Storage ============

    AuctionStatus public auctionStatus;
    uint256 public totalContributedToParty;
    uint256 public totalContributionsClaimed;
    uint256 public highestBid;
    uint256 public highestBidPlusFee;
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

    //======== Constructor =========

    constructor(
        NFTType _nftType,
        uint256 _tokenId,
        uint256 _quorumPercent,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        // validate the NFT type
        require(
            _nftType == NFTType.Zora || _nftType == NFTType.Foundation,
            "!valid nft type"
        );
        address _nftContract =
            _nftType == NFTType.Zora
                ? ZORA_NFT_CONTRACT
                : FOUNDATION_NFT_CONTRACT;
        // validate tokenID - this call should revert if the token does not exist
        // TODO: deploy Zora / Foundation contracts at given addresses for tests & create NFTs
        // IERC721(_nftContract).tokenURI(_tokenId);
        // validate quorum percent
        require(_quorumPercent <= 100, "!valid quorum");
        // set storage variables
        nftContract = _nftContract;
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
        uint256 _currentBalance = address(this).balance;
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
     * @notice Submit a bid to the NFT
     * @dev Emits a Bid event upon success; callable by any contributor
     */
    function bid() external nonReentrant {
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        require(totalContributed[msg.sender] > 0, "only contributors can bid");
        // TODO: implement
        // get current highest bid / bidder
        // if not current highest bidder
        // & there is enough ETH in contract for highest bid * 1.1 bid increment * 1.05 PartyDAO fee,
        // submit bid to Auction contract
        emit Bid(0);
    }

    //======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external nonReentrant {
        require(auctionStatus == AuctionStatus.ACTIVE, "auction not active");
        // TODO: implement
        // verify the auction is over / determine result
        AuctionStatus _result;
        // if the auction was won,
        // _result = AuctionStatus.WON;
        // transfer the NFT to address(this) (if not already done)
        // transfer 5% fee to PartyDAO
        // mint total token supply to PartyBid
        // _mint(address(this), valueToTokens(totalContributedToParty));
        // if the auction was lost,
        // _result = AuctionStatus.LOST;
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
     */
    function claim(address _contributor) external nonReentrant {
        // load auction status once from storage
        AuctionStatus _auctionStatus = auctionStatus;
        // ensure auction has finalized
        require(
            _auctionStatus != AuctionStatus.ACTIVE,
            "auction not finalized"
        );
        _claim(_contributor, _auctionStatus);
    }

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a a batch of contributors after the auction has ended
     * @dev Emits a Claimed event upon success,
     * reverts if any of the contributors' claims fails
     */
    function claim(address[] calldata _contributors) external nonReentrant {
        // load auction status once from storage
        AuctionStatus _auctionStatus = auctionStatus;
        // ensure auction has finalized
        require(
            _auctionStatus != AuctionStatus.ACTIVE,
            "auction not finalized"
        );
        for (uint256 i = 0; i < _contributors.length; i++) {
            _claim(_contributors[i], _auctionStatus);
        }
    }

    // ======== Public: Utility =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 value) public pure returns (uint256 tokens) {
        tokens = value * (TOKEN_SCALE);
    }

    // ============ Internal: Claim ============

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a single contributor after the auction has ended
     * @dev Emits a Claimed event upon success
     */
    function _claim(address _contributor, AuctionStatus _auctionStatus)
        internal
    {
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
        uint256 _totalSpent = highestBidPlusFee;
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
