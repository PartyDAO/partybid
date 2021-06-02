// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

// ============ Internal Imports ============
import {PartyBidStorage} from "./PartyBidStorage.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 */
contract PartyBidLogic is PartyBidStorage {
    // Use OpenZeppelin's SafeMath library to prevent overflows.
    using SafeMath for uint256;

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

    // ============ ERC-20 Events ============

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // ============ Modifiers ============

    /**
     * @notice Prevent re-entrancy attacks
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(reentrancyStatus != REENTRANCY_ENTERED, "no reentrance");
        // Any calls to nonReentrant after this point will fail
        reentrancyStatus = REENTRANCY_ENTERED;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        reentrancyStatus = REENTRANCY_NOT_ENTERED;
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
        require(
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "contributions closed"
        );
        require(_amount == msg.value, "amount != value");
        // get the current contract balance
        uint256 _previousTotalContributedToParty = totalContributedToParty;
        // add contribution to contributor's array of contributions
        Contribution memory _contribution =
            Contribution({amount: _amount, previousTotalContributedToParty: _previousTotalContributedToParty});
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] = totalContributed[_contributor].add(
            _amount
        );
        // add to party's total contribution & emit event
        totalContributedToParty = totalContributedToParty.add(_amount);
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
            "auction not active"
        );
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
        require(
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "auction not active"
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
        // if the auction was won,
        if (_result == PartyStatus.AUCTION_WON) {
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
        partyStatus = _result;
        emit Finalized(_result, totalSpent);
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
            "auction not finalized"
        );
        // load amount contributed once from storage
        uint256 _totalContributed = totalContributed[_contributor];
        // ensure contributor submitted some ETH
        require(_totalContributed != 0, "! a contributor");
        uint256 _tokenAmount;
        uint256 _excessContribution;
        if (_partyStatus == PartyStatus.AUCTION_WON) {
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
        } else if (_partyStatus == PartyStatus.AUCTION_LOST) {
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

    /**
     * @notice Signal support for a reseller.
     * Used to support a reseller for the first time (e.g. proposing a reseller)
     * AND to add subsequent support (e.g. vote in favor).
     * Only original contributors whose ETH was spent have voting power;
     * voting power can never be transferred or burned.
     * Anyone with voting power can add support for as many resellers as they wish.
     * Once support is added, it cannot be removed.
     * There is no function to vote *AGAINST* a reseller - support can only be added.
     * Once a reseller gains enough support to surpass quorum,
     * the reseller is automatically finalized; the NFT is transferred
     * to the reseller and no further votes can be submitted.
     * @dev Emits a ResellerSupported event each time support is added;
     * Emits a ResellerApproved event when the reseller is finalized
     * @param _reseller the address of the reseller to support
     * @param _resellerCalldata the calldata that will be called on the _reseller
     * when it is confirmed; empty for EOA resellers or if no function call is desired.
     * Combination of _reseller + _resellerCalldata is like a "proposal" - submitting different
     * calldata is an entirely different proposal whose votes start at zero.
     */
    function supportReseller(
        address _reseller,
        bytes calldata _resellerCalldata
    ) external nonReentrant {
        // voting only possible after the auction has been won
        // and before the reseller has been finalized
        require(partyStatus == PartyStatus.AUCTION_WON, "voting not open");
        // ensure the caller has some voting power
        uint256 _votingPower = votingPower[msg.sender];
        require(_votingPower > 0, "no voting power");
        // require that the caller has not already supported the reseller
        require(
            !hasSupportedReseller[msg.sender][_reseller][_resellerCalldata],
            "already supported this reseller"
        );
        // get the prior votes in support of this reseller
        uint256 _currentSupport = resellerSupport[_reseller][_resellerCalldata];
        // if this is a newly proposed reseller, ensure that they are whitelisted
        bool _isApprovedReseller = _currentSupport > 0;
        require(
            _isApprovedReseller ||
                resellerWhitelist.isWhitelisted(address(this), _reseller),
            "reseller !whitelisted"
        );
        // update support for reseller
        uint256 _updatedSupport = _currentSupport.add(_votingPower);
        resellerSupport[_reseller][_resellerCalldata] = _updatedSupport;
        hasSupportedReseller[msg.sender][_reseller][_resellerCalldata] = true;
        // emit event
        emit ResellerSupported(
            _reseller,
            msg.sender,
            _votingPower,
            _updatedSupport
        );
        // if updated support passes quorum, transfer the NFT to the reseller & close voting
        if (_updatedSupport >= supportNeededForQuorum) {
            _finalizeReseller(_reseller, _resellerCalldata);
        }
    }

    // ======== External: Redeem =========

    /**
     * @notice Burn a portion of ERC-20 tokens in exchange for
     * a proportional amount of the redeemable ETH balance of the contract.
     * Users are at discretion to determine when resale proceeds have been deposited,
     * but there are guard rails to prevent mistaken redeems
     * Note: Excess auction contributions must be retrieved via claim()
     * @dev Emits a Redeem event upon success
     * @param _tokenAmount the amount of tokens to burn for ETH
     */
    function redeem(uint256 _tokenAmount) external nonReentrant {
        // token holders shouldn't redeem before the NFT has been sent to the reseller
        require(partyStatus == PartyStatus.NFT_TRANSFERRED, "nft not resold");
        // token holders shouldn't redeem zero tokens
        require(_tokenAmount != 0, "can't redeem zero tokens");
        require(
            balanceOf[msg.sender] >= _tokenAmount,
            "redeem amount exceeds balance"
        );
        uint256 _redeemAmount = redeemAmount(_tokenAmount);
        // token holders shouldn't burn tokens in exchange for zero ETH
        require(_redeemAmount > 0, "can't redeem for 0 ETH");
        // burn redeemed tokens
        _burn(msg.sender, _tokenAmount);
        // transfer redeem amount to recipient
        _transferETHOrWETH(msg.sender, _redeemAmount);
        // emit event
        emit Redeemed(msg.sender, _tokenAmount, _redeemAmount);
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
        _maxBid = totalContributedToParty.sub(_getFee(totalContributedToParty));
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
            _contribution.previousTotalContributedToParty.add(_contribution.amount) <=
            _totalSpent
        ) {
            // contribution was fully used
            _amount = _contribution.amount;
        } else if (_contribution.previousTotalContributedToParty < _totalSpent) {
            // contribution was partially used
            _amount = _totalSpent.sub(_contribution.previousTotalContributedToParty);
        } else {
            // contribution was not used
            _amount = 0;
        }
    }

    // ============ Internal: SupportReseller ============

    /**
     * @notice Transfer the NFT to the reseller
     * and switch status to close further voting
     * @dev Emits a ResellerApproved event
     * @param _reseller the address of the reseller being finalized
     * @param _resellerCalldata the calldata that will be sent if non-null
     */
    function _finalizeReseller(
        address _reseller,
        bytes memory _resellerCalldata
    ) internal {
        // transfer the NFT to the reseller
        nftContract.transferFrom(address(this), _reseller, tokenId);
        // call the reseller with the provided data
        if (_resellerCalldata.length > 0) {
            (bool success, ) = _reseller.call(_resellerCalldata);
            require(success, "reseller call failed");
        }
        // change status in order to close voting & emit event
        partyStatus = PartyStatus.NFT_TRANSFERRED;
        emit ResellerApproved(_reseller);
    }

    // ============ Internal: TransferEthOrWeth ============

    /**
     * @notice Attempt to transfer ETH to a recipient;
     * if transferring ETH fails, transfer WETH insteads
     * @param _to recipient of ETH or WETH
     * @param _value amount of ETH or WETH
     */
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(_to, _value)) {
            // If the transfer fails, wrap and send as WETH
            WETH.deposit{value: _value}();
            WETH.transfer(_to, _value);
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

    // ============ ERC-20 Spec ============
    // ============ ERC-20 External ============

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        _transfer(from, to, value);
        return true;
    }

    // ============ ERC-20 Internal ============

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }
}
