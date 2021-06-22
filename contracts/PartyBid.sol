// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ External Imports: Inherited Contracts ============
// NOTE: we inherit ReentrancyGuardUpgradeable
// because of the proxy structure used for cheaper deploys
// (the proxies are NOT actually upgradeable)
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
// ============ External Imports: External Contracts & Contract Interfaces ============
import {IERC721VaultFactory} from "./external/interfaces/IERC721VaultFactory.sol";
import {ITokenVault} from "./external/interfaces/ITokenVault.sol";
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./market-wrapper/IMarketWrapper.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 */
contract PartyBid is ReentrancyGuardUpgradeable {
    // ============ Enums ============

    // State Transitions:
    //   (1) AUCTION_ACTIVE on deploy
    //   (2) AUCTION_WON or AUCTION_LOST on finalize()
    enum PartyStatus {AUCTION_ACTIVE, AUCTION_WON, AUCTION_LOST}

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        uint256 previousTotalContributedToParty;
    }

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyBid pays a 5% fee to PartyDAO
    uint8 internal constant FEE_PERCENT = 5;

    // ============ Immutables ============

    address public immutable partyDAOMultisig;
    address public immutable tokenVaultFactory;
    address public immutable weth;

    // ============ Public Not-Mutated Storage ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // NFT contract
    IERC721Metadata public nftContract;
    // Fractionalized NFT vault responsible for post-auction value capture
    address public tokenVault;
    uint256 public auctionId;
    uint256 public tokenId;
    string public name;
    string public symbol;

    // ============ Public Mutable Storage ============

    // state of the contract
    PartyStatus public partyStatus;
    // total ETH deposited by all contributors
    uint256 public totalContributedToParty;
    // the highest bid submitted by PartyBid
    uint256 public highestBid;
    // the total spent by PartyBid on the auction;
    // 0 if the NFT is lost; highest bid + 5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;
    // contributor => true if contribution has been claimed
    mapping(address => bool) public claimed;

    // ============ Events ============

    event Contributed(
        address indexed contributor,
        uint256 amount,
        uint256 previousTotalContributedToParty,
        uint256 totalFromContributor
    );

    event Bid(uint256 amount);

    event Finalized(PartyStatus result, uint256 totalSpent);

    event Claimed(
        address indexed contributor,
        uint256 totalContributed,
        uint256 excessContribution,
        uint256 tokenAmount
    );

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) {
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = _tokenVaultFactory;
        weth = _weth;
    }

    // ======== Initializer =========

    function initialize(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        string memory _name,
        string memory _symbol
    ) external initializer {
        // initialize ReentrancyGuard and ERC20
        __ReentrancyGuard_init();
        // set storage variables
        marketWrapper = IMarketWrapper(_marketWrapper);
        nftContract = IERC721Metadata(_nftContract);
        tokenId = _tokenId;
        auctionId = _auctionId;
        name = _name;
        symbol = _symbol;
        // validate token exists - this call should revert if not
        nftContract.tokenURI(_tokenId);
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
     * @notice Contribute to the PartyBid's treasury
     * while the auction is still open
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute() external payable nonReentrant {
        require(
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "PartyBid::contribute: auction not active"
        );
        address _contributor = msg.sender;
        uint256 _amount = msg.value;
        // get the current contract balance
        uint256 _previousTotalContributedToParty = totalContributedToParty;
        // add contribution to contributor's array of contributions
        Contribution memory _contribution =
            Contribution({
                amount: _amount,
                previousTotalContributedToParty: _previousTotalContributedToParty
            });
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] = totalContributed[_contributor] + _amount;
        // add to party's total contribution & emit event
        totalContributedToParty = totalContributedToParty + _amount;
        emit Contributed(
            _contributor,
            _amount,
            _previousTotalContributedToParty,
            totalContributed[_contributor]
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
        require(
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "PartyBid::bid: auction not active"
        );
        require(totalContributed[msg.sender] > 0, "PartyBid::bid: only contributors can bid");
        require(
            address(this) != marketWrapper.getCurrentHighestBidder(auctionId),
            "PartyBid::bid: already highest bidder"
        );
        // get the minimum next bid for the auction
        uint256 _bid = marketWrapper.getMinimumBid(auctionId);
        // ensure there is enough ETH to place the bid including PartyDAO fee
        require(_bid <= _getMaximumBid(), "PartyBid::bid: insufficient funds to bid");
        // submit bid to Auction contract using delegatecall
        (bool success, bytes memory returnData) =
            address(marketWrapper).delegatecall(
                abi.encodeWithSignature("bid(uint256,uint256)", auctionId, _bid)
            );
        require(success, string(abi.encodePacked("PartyBid::bid: place bid failed: ", returnData)));
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
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "PartyBid::finalize: auction not active"
        );
        // finalize auction if it hasn't already been done
        if (!marketWrapper.isFinalized(auctionId)) {
            marketWrapper.finalize(auctionId);
        }
        // after the auction has been finalized,
        // if the NFT is owned by the PartyBid, then the PartyBid won the auction
        PartyStatus _result =
            nftContract.ownerOf(tokenId) == address(this)
                ? PartyStatus.AUCTION_WON
                : PartyStatus.AUCTION_LOST;
        partyStatus = _result;
        // if the auction was won,
        uint256 _totalSpent;
        if (_result == PartyStatus.AUCTION_WON) {
            // transfer 5% fee to PartyDAO
            uint256 _fee = _getFee(highestBid);
            _transferETHOrWETH(partyDAOMultisig, _fee);
            // record total spent by auction + PartyDAO fees
            _totalSpent = highestBid + _fee;
            totalSpent = _totalSpent;
            // approve fractionalized NFT Factory to withdraw NFT
            IERC721Metadata(nftContract).approve(tokenVaultFactory, tokenId);
            // deploy fractionalized NFT vault
            uint256 vaultNumber =
                IERC721VaultFactory(tokenVaultFactory).mint(
                    name,
                    symbol,
                    address(nftContract),
                    tokenId,
                    valueToTokens(_totalSpent),
                    _totalSpent,
                    0
                );
            // store vault address
            tokenVault = address(
                IERC721VaultFactory(tokenVaultFactory).vaults(vaultNumber)
            );
            // transfer curator to null address
            ITokenVault(tokenVault).updateCurator(address(0));
        }
        // set the contract status & emit result
        emit Finalized(_result, _totalSpent);
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
        // load party status once from storage
        PartyStatus _partyStatus = partyStatus;
        // ensure auction has finalized
        require(
            _partyStatus != PartyStatus.AUCTION_ACTIVE,
            "PartyBid::claim: auction not finalized"
        );
        // load amount contributed once from storage
        uint256 _totalContributed = totalContributed[_contributor];
        // ensure contributor submitted some ETH
        require(_totalContributed != 0, "PartyBid::claim: not a contributor");
        // ensure the contributor hasn't already claimed
        require(!claimed[_contributor], "PartyBid::claim: contribution already claimed");
        claimed[_contributor] = true;
        uint256 _tokenAmount;
        uint256 _excessContribution;
        if (_partyStatus == PartyStatus.AUCTION_WON) {
            // calculate the amount of this contributor's ETH
            // that was used for the winning bid
            uint256 _totalUsedForBid = _totalEthUsedForBid(_contributor);
            if (_totalUsedForBid > 0) {
                _tokenAmount = valueToTokens(_totalUsedForBid);
                // guard against rounding errors;
                // if _tokenAmount to send is greater than contract balance,
                // send full contract balance
                uint256 _totalBalance = ITokenVault(tokenVault).balanceOf(address(this));
                if (_tokenAmount > _totalBalance) {
                    _tokenAmount = _totalBalance;
                }
                // transfer tokens to contributor for their portion of ETH used
                ITokenVault(tokenVault).transfer(_contributor, _tokenAmount);
            }
            // return the rest of the contributor's ETH
            _excessContribution = _totalContributed - _totalUsedForBid;
        } else if (_partyStatus == PartyStatus.AUCTION_LOST) {
            // return all of the contributor's ETH
            _excessContribution = _totalContributed;
        }
        // if there is excess ETH, send it back to the contributor
        if (_excessContribution > 0) {
            _transferETHOrWETH(_contributor, _excessContribution);
        }
        emit Claimed(
            _contributor,
            _totalContributed,
            _excessContribution,
            _tokenAmount
        );
    }

    // ======== Public: Utility Calculations =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 _value)
        public
        pure
        returns (uint256 _tokens)
    {
        _tokens = _value * TOKEN_SCALE;
    }

    // ============ Internal: Bid ============

    /**
     * @notice The maximum bid that can be submitted
     * while leaving 5% fee for PartyDAO
     * @return _maxBid the maximum bid
     */
    function _getMaximumBid() internal view returns (uint256 _maxBid) {
        _maxBid = totalContributedToParty - _getFee(totalContributedToParty);
    }

    /**
     * @notice Calculate 5% fee for PartyDAO
     * @return _fee 5% of the given amount
     */
    function _getFee(uint256 _amount) internal pure returns (uint256 _fee) {
        _fee = (_amount * FEE_PERCENT) / 100;
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
            _total = _total + _amount;
        }
    }

    /**
     * @notice Calculate the amount that was used towards
     * the winning auction bid from a single Contribution
     * @param _contribution the Contribution struct
     * @return the amount of funds from this contribution
     * that were used towards the winning auction bid
     */
    function _ethUsedForBid(Contribution memory _contribution)
        internal
        view
        returns (uint256)
    {
        // load total amount spent once from storage
        uint256 _totalSpent = totalSpent;
        if (
            _contribution.previousTotalContributedToParty + _contribution.amount <= _totalSpent
        ) {
            // contribution was fully used
            return _contribution.amount;
        } else if (
            _contribution.previousTotalContributedToParty < _totalSpent
        ) {
            // contribution was partially used
            return _totalSpent - _contribution.previousTotalContributedToParty;
        }
        // contribution was not used
        return 0;
    }

    // ============ Internal: TransferEthOrWeth ============

    /**
     * @notice Attempt to transfer ETH to a recipient;
     * if transferring ETH fails, transfer WETH insteads
     * @param _to recipient of ETH or WETH
     * @param _value amount of ETH or WETH
     */
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // guard against rounding errors;
        // if ETH amount to send is greater than contract balance,
        // send full contract balance
        if(_value > address(this).balance) {
            _value = address(this).balance;
        }
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(_to, _value)) {
            // If the transfer fails, wrap and send as WETH
            IWETH(weth).deposit{value: _value}();
            IWETH(weth).transfer(_to, _value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    /**
     * @notice Attempt to transfer ETH to a recipient
     * @dev Sending ETH is not guaranteed to succeed
     * this method will return false if it fails.
     * We will limit the gas used in transfers, and handle failure cases.
     * @param _to recipient of ETH
     * @param _value amount of ETH
     */
    function _attemptETHTransfer(address _to, uint256 _value)
        internal
        returns (bool)
    {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}
