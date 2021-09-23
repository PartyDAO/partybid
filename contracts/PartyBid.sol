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

PartyBid v1
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

contract PartyBid is ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
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

    // PartyBid version 2
    uint16 public constant VERSION = 2;
    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyDAO receives an ETH fee equal to 2.5% of the winning bid
    uint16 internal constant ETH_FEE_BASIS_POINTS = 250;
    // PartyDAO receives a token fee equal to 2.5% of the total token supply
    uint16 internal constant TOKEN_FEE_BASIS_POINTS = 250;
    // token is relisted on Fractional with an
    // initial reserve price equal to 2x the winning bid
    uint8 internal constant RESALE_MULTIPLIER = 2;

    // ============ Immutables ============

    address public immutable partyDAOMultisig;
    IERC721VaultFactory public immutable tokenVaultFactory;
    IWETH public immutable weth;

    // ============ Public Not-Mutated Storage ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // NFT contract
    IERC721Metadata public nftContract;
    // Fractionalized NFT vault responsible for post-auction value capture
    ITokenVault public tokenVault;
    // ID of auction within market contract
    uint256 public auctionId;
    // ID of token within NFT contract
    uint256 public tokenId;
    // the address that will receive a portion of the tokens
    // if the PartyBid wins the auction
    address public splitRecipient;
    // percent of the total token supply
    // taken by the splitRecipient
    uint256 public splitBasisPoints;
    // ERC-20 name and symbol for fractional tokens
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
    // 0 if the NFT is lost; highest bid + 2.5% PartyDAO fee if NFT is won
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

    event Finalized(PartyStatus result, uint256 totalSpent, uint256 fee, uint256 totalContributed);

    event Claimed(
        address indexed contributor,
        uint256 totalContributed,
        uint256 excessContribution,
        uint256 tokenAmount
    );

    // ======== Modifiers =========

    modifier onlyPartyDAO() {
        require(
            msg.sender == partyDAOMultisig,
            "PartyBid:: only PartyDAO multisig"
        );
        _;
    }

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) {
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = IERC721VaultFactory(_tokenVaultFactory);
        weth = IWETH(_weth);
    }

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
        require(_amount > 0, "PartyBid::contribute: must contribute more than 0");
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
        totalContributed[_contributor] =
            totalContributed[_contributor] +
            _amount;
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
            partyStatus == PartyStatus.AUCTION_ACTIVE,
            "PartyBid::finalize: auction not active"
        );
        // finalize auction if it hasn't already been done
        if (!marketWrapper.isFinalized(auctionId)) {
            marketWrapper.finalize(auctionId);
        }
        // after the auction has been finalized,
        // if the NFT is owned by the PartyBid, then the PartyBid won the auction
        address _owner = _getOwner();
        partyStatus = _owner == address(this) ? PartyStatus.AUCTION_WON : PartyStatus.AUCTION_LOST;
        uint256 _ethFee;
        // if the auction was won,
        if (partyStatus == PartyStatus.AUCTION_WON) {
            // calculate PartyDAO fee & record total spent
            _ethFee = _getEthFee(highestBid);
            totalSpent = highestBid + _ethFee;
            // transfer ETH fee to PartyDAO
            _transferETHOrWETH(partyDAOMultisig, _ethFee);
            // deploy fractionalized NFT vault
            // and mint fractional ERC-20 tokens
            _fractionalizeNFT();
        }
        // set the contract status & emit result
        emit Finalized(partyStatus, totalSpent, _ethFee, totalContributedToParty);
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
        // ensure auction has finalized
        require(
            partyStatus != PartyStatus.AUCTION_ACTIVE,
            "PartyBid::claim: auction not finalized"
        );
        // ensure contributor submitted some ETH
        require(
            totalContributed[_contributor] != 0,
            "PartyBid::claim: not a contributor"
        );
        // ensure the contributor hasn't already claimed
        require(
            !claimed[_contributor],
            "PartyBid::claim: contribution already claimed"
        );
        // mark the contribution as claimed
        claimed[_contributor] = true;
        // calculate the amount of fractional NFT tokens owed to the user
        // based on how much ETH they contributed towards the auction,
        // and the amount of excess ETH owed to the user
        (uint256 _tokenAmount, uint256 _ethAmount) =
            getClaimAmounts(_contributor);
        // transfer tokens to contributor for their portion of ETH used
        _transferTokens(_contributor, _tokenAmount);
        // if there is excess ETH, send it back to the contributor
        _transferETHOrWETH(_contributor, _ethAmount);
        emit Claimed(
            _contributor,
            totalContributed[_contributor],
            _ethAmount,
            _tokenAmount
        );
    }

    // ======== External: Emergency Escape Hatches (PartyDAO Multisig Only) =========

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyWithdrawEth to withdraw
     * ETH stuck in the contract
     */
    function emergencyWithdrawEth(uint256 _value)
        external
        onlyPartyDAO
    {
        _transferETHOrWETH(partyDAOMultisig, _value);
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyCall to call an external contract
     * (e.g. to withdraw a stuck NFT or stuck ERC-20s)
     */
    function emergencyCall(address _contract, bytes memory _calldata)
        external
        onlyPartyDAO
        returns (bool _success, bytes memory _returnData)
    {
        (_success, _returnData) = _contract.call(_calldata);
        require(_success, string(_returnData));
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can force the PartyBid to finalize with status LOST
     * (e.g. if finalize is not callable)
     */
    function emergencyForceLost()
        external
        onlyPartyDAO
    {
        // set partyStatus to LOST
        partyStatus = PartyStatus.AUCTION_LOST;
        // emit Finalized event
        emit Finalized(partyStatus, 0, 0, totalContributedToParty);
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

    /**
     * @notice The maximum bid that can be submitted
     * while paying the ETH fee to PartyDAO
     * @return _maxBid the maximum bid
     */
    function getMaximumBid() public view returns (uint256 _maxBid) {
        _maxBid = (totalContributedToParty * 10000) / (10000 + ETH_FEE_BASIS_POINTS);
    }

    /**
     * @notice Calculate the amount of fractional NFT tokens owed to the contributor
     * based on how much ETH they contributed towards the auction,
     * and the amount of excess ETH owed to the contributor
     * based on how much ETH they contributed *not* used towards the auction
     * @param _contributor the address of the contributor
     * @return _tokenAmount the amount of fractional NFT tokens owed to the contributor
     * @return _ethAmount the amount of excess ETH owed to the contributor
     */
    function getClaimAmounts(address _contributor)
        public
        view
        returns (uint256 _tokenAmount, uint256 _ethAmount)
    {
        require(partyStatus != PartyStatus.AUCTION_ACTIVE, "PartyBid::getClaimAmounts: party still active; amounts undetermined");
        uint256 _totalContributed = totalContributed[_contributor];
        if (partyStatus == PartyStatus.AUCTION_WON) {
            // calculate the amount of this contributor's ETH
            // that was used for the winning bid
            uint256 _totalUsedForBid = totalEthUsedForBid(_contributor);
            if (_totalUsedForBid > 0) {
                _tokenAmount = valueToTokens(_totalUsedForBid);
            }
            // the rest of the contributor's ETH should be returned
            _ethAmount = _totalContributed - _totalUsedForBid;
        } else {
            // if the auction was lost, no ETH was spent;
            // all of the contributor's ETH should be returned
            _ethAmount = _totalContributed;
        }
    }

    /**
     * @notice Calculate the total amount of a contributor's funds
     * that were used towards the winning auction bid
     * @dev always returns 0 until the auction has been finalized
     * @param _contributor the address of the contributor
     * @return _total the sum of the contributor's funds that were
     * used towards the winning auction bid
     */
    function totalEthUsedForBid(address _contributor)
        public
        view
        returns (uint256 _total)
    {
        require(partyStatus != PartyStatus.AUCTION_ACTIVE, "PartyBid::totalEthUsedForBid: party still active; amounts undetermined");
        // load total amount spent once from storage
        uint256 _totalSpent = totalSpent;
        // get all of the contributor's contributions
        Contribution[] memory _contributions = contributions[_contributor];
        for (uint256 i = 0; i < _contributions.length; i++) {
            // calculate how much was used from this individual contribution
            uint256 _amount = _ethUsedForBid(_totalSpent, _contributions[i]);
            // if we reach a contribution that was not used,
            // no subsequent contributions will have been used either,
            // so we can stop calculating to save some gas
            if (_amount == 0) break;
            _total = _total + _amount;
        }
    }

    // ============ Internal: Bid ============

    /**
     * @notice Calculate ETH fee for PartyDAO
     * NOTE: Remove this fee causes a critical vulnerability
     * allowing anyone to exploit a PartyBid via price manipulation.
     * See Security Review in README for more info.
     * @return _fee the portion of _amount represented by scaling to ETH_FEE_BASIS_POINTS
     */
    function _getEthFee(uint256 _winningBid) internal pure returns (uint256 _fee) {
        _fee = (_winningBid * ETH_FEE_BASIS_POINTS) / 10000;
    }

    /**
     * @notice Calculate token amount for specified token recipient
     * @return _totalSupply the total token supply
     * @return _partyDAOAmount the amount of tokens for partyDAO fee,
     * which is equivalent to TOKEN_FEE_BASIS_POINTS of total supply
     * @return _splitRecipientAmount the amount of tokens for the token recipient,
     * which is equivalent to splitBasisPoints of total supply
     */
    function _getTokenInflationAmounts(uint256 _winningBid)
        internal
        view
        returns (uint256 _totalSupply, uint256 _partyDAOAmount, uint256 _splitRecipientAmount)
    {
        // the token supply will be inflated to provide a portion of the
        // total supply for PartyDAO, and a portion for the splitRecipient
        uint256 inflationBasisPoints = TOKEN_FEE_BASIS_POINTS + splitBasisPoints;
        _totalSupply = valueToTokens((_winningBid * 10000) / (10000 - inflationBasisPoints));
        // PartyDAO receives TOKEN_FEE_BASIS_POINTS of the total supply
        _partyDAOAmount = (_totalSupply * TOKEN_FEE_BASIS_POINTS) / 10000;
        // splitRecipient receives splitBasisPoints of the total supply
        _splitRecipientAmount = (_totalSupply * splitBasisPoints) / 10000;
    }

    // ============ Internal: Finalize ============

    /**
    * @notice Query the NFT contract to get the token owner
    * @dev nftContract must implement the ERC-721 token standard exactly:
    * function ownerOf(uint256 _tokenId) external view returns (address);
    * See https://eips.ethereum.org/EIPS/eip-721
    * @dev Returns address(0) if NFT token or NFT contract
    * no longer exists (token burned or contract self-destructed)
    * @return _owner the owner of the NFT
    */
    function _getOwner() internal view returns (address _owner) {
        (bool success, bytes memory returnData) =
            address(nftContract).staticcall(
                abi.encodeWithSignature(
                    "ownerOf(uint256)",
                    tokenId
                )
        );
        if (success && returnData.length > 0) {
            _owner = abi.decode(returnData, (address));
        }
    }

    /**
     * @notice Upon winning the auction, transfer the NFT
     * to fractional.art vault & mint fractional ERC-20 tokens
     */
    function _fractionalizeNFT() internal {
        // approve fractionalized NFT Factory to withdraw NFT
        nftContract.approve(address(tokenVaultFactory), tokenId);
        // PartyBid "votes" for a reserve price on Fractional
        // equal to 2x the winning bid
        uint256 _listPrice = RESALE_MULTIPLIER * highestBid;
        // users receive tokens at a rate of 1:TOKEN_SCALE for each ETH they contributed that was ultimately spent
        // partyDAO receives a percentage of the total token supply equivalent to TOKEN_FEE_BASIS_POINTS
        // splitRecipient receives a percentage of the total token supply equivalent to splitBasisPoints
        (uint256 _tokenSupply, uint256 _partyDAOAmount, uint256 _splitRecipientAmount) = _getTokenInflationAmounts(totalSpent);
        // deploy fractionalized NFT vault
        uint256 vaultNumber =
            tokenVaultFactory.mint(
                name,
                symbol,
                address(nftContract),
                tokenId,
                _tokenSupply,
                _listPrice,
                0
            );
        // store token vault address to storage
        tokenVault = ITokenVault(tokenVaultFactory.vaults(vaultNumber));
        // transfer curator to null address (burn the curator role)
        tokenVault.updateCurator(address(0));
        // transfer tokens to PartyDAO multisig
        _transferTokens(partyDAOMultisig, _partyDAOAmount);
        // transfer tokens to token recipient
        if (splitRecipient != address(0)) {
            _transferTokens(splitRecipient, _splitRecipientAmount);
        }
    }

    // ============ Internal: Claim ============

    /**
     * @notice Calculate the amount that was used towards
     * the winning auction bid from a single Contribution
     * @param _contribution the Contribution struct
     * @return the amount of funds from this contribution
     * that were used towards the winning auction bid
     */
    function _ethUsedForBid(uint256 _totalSpent, Contribution memory _contribution)
        internal
        view
        returns (uint256)
    {
        if (
            _contribution.previousTotalContributedToParty +
                _contribution.amount <=
            _totalSpent
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

    // ============ Internal: TransferTokens ============

    /**
    * @notice Transfer tokens to a recipient
    * @param _to recipient of tokens
    * @param _value amount of tokens
    */
    function _transferTokens(address _to, uint256 _value) internal {
        // skip if attempting to send 0 tokens
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if token amount to send is greater than contract balance,
        // send full contract balance
        uint256 _partyBidBalance = tokenVault.balanceOf(address(this));
        if (_value > _partyBidBalance) {
            _value = _partyBidBalance;
        }
        tokenVault.transfer(_to, _value);
    }

    // ============ Internal: TransferEthOrWeth ============

    /**
     * @notice Attempt to transfer ETH to a recipient;
     * if transferring ETH fails, transfer WETH insteads
     * @param _to recipient of ETH or WETH
     * @param _value amount of ETH or WETH
     */
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // skip if attempting to send 0 ETH
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if ETH amount to send is greater than contract balance,
        // send full contract balance
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(_to, _value)) {
            // If the transfer fails, wrap and send as WETH
            weth.deposit{value: _value}();
            weth.transfer(_to, _value);
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
