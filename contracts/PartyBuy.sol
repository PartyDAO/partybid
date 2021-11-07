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
import {IERC721VaultFactory} from "./external/interfaces/IERC721VaultFactory.sol";
import {ITokenVault} from "./external/interfaces/ITokenVault.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";
import {Party} from "./Party.sol";

contract PartyBuy is Party {
    // partyStatus Transitions:
    //   (1) PartyStatus.ACTIVE on deploy
    //   (2) PartyStatus.WON after successful buy()
    //   (3) PartyStatus.LOST after successful fail()

    // ============ Internal Constants ============

    // PartyBuy version 1
    uint16 public constant VERSION = 1;

    // ============ Public Not-Mutated Storage ============

    // the timestamp at which the Party can be canceled
    uint256 public timeoutAt;

    // ============ Public Mutable Storage ============

    // the maximum price that the party is willing to
    // spend on the token
    // NOTE: the party can spend *UP TO* 102.5% of maxPrice in total,
    // and will not accept more contributions than this max amount
    uint256 public maxPrice;

    // ============ Events ============

    // emitted when the token is successfully bought
    event Bought(address triggeredBy, address targetAddress, uint256 ethPrice, uint256 ethFee, uint256 totalContributed);

    // emitted if the Party fails to buy the token before timeoutAt
    // and someone closes the Party so folks can reclaim ETH
    event Closed();

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) Party(_partyDAOMultisig, _tokenVaultFactory, _weth) {}

    // ======== Initializer =========

    function initialize(
        address _nftContract,
        uint256 _tokenId,
        uint256 _maxPrice,
        uint256 _secondsToTimeout,
        address _splitRecipient,
        uint256 _splitBasisPoints,
        string memory _name,
        string memory _symbol
    ) external initializer {
        // initialize ReentrancyGuard and ERC721Holder
        __ReentrancyGuard_init();
        __ERC721Holder_init();
        // set storage variables
        nftContract = IERC721Metadata(_nftContract);
        tokenId = _tokenId;
        name = _name;
        symbol = _symbol;
        timeoutAt = _secondsToTimeout + block.timestamp;
        require(_maxPrice > 0, "PartyBuy::initialize: must set price higher than 0");
        maxPrice = _maxPrice;
        // validate that party split won't retain the total token supply
        uint256 _remainingBasisPoints = 10000 - TOKEN_FEE_BASIS_POINTS;
        require(_splitBasisPoints < _remainingBasisPoints, "PartyBuy::initialize: basis points can't take 100%");
        // validate that a portion of the token supply is not being burned
        if (_splitRecipient == address(0)) {
            require(_splitBasisPoints == 0, "PartyBuy::initialize: can't send tokens to burn addr");
        }
        splitBasisPoints = _splitBasisPoints;
        splitRecipient = _splitRecipient;
        // validate token exists
        require(_getOwner() != address(0), "PartyBuy::initialize: NFT getOwner failed");
    }

    // ======== External: Contribute =========

    /**
     * @notice Contribute to the Party's treasury
     * while the Party is still active
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute() external payable nonReentrant {
        // require that the new total contributed is not greater than
        // the maximum amount the Party is willing to spend
        require(totalContributedToParty + msg.value <= getMaximumContributions(), "PartyBuy::contribute: cannot contribute more than max");
        // continue with shared _contribute flow
        _contribute();
    }

    // ======== External: Buy =========

    /**
     * @notice Buy the token by calling targetContract with calldata supplying value
     * @dev Emits a Bought event upon success; reverts otherwise. callable by anyone
     */
    function buy(uint256 _value, address _targetContract, bytes calldata _calldata) external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBuy::buy: party not active"
        );
        // get the contract balance before the call
        uint256 _balanceBeforeCall = address(this).balance;
        // execute the calldata on the target contract
        address(_targetContract).call{value: _value}(_calldata);
        // NOTE: we don't are if the call succeeded
        // as long as the NFT is owned by the Party
        require(_getOwner() == address(this), "PartyBuy::buy: failed to buy token");
        // get the contract balance after the call
        uint256 _balanceAfterCall = address(this).balance;
        // the ETH amount spent is transformed to the total token supply,
        // so it can't be 0 or else the NFT will be burned in the Fractional vault
        require(_balanceAfterCall < _balanceBeforeCall, "PartyBuy::buy: must spend more than 0 on token");
        // calculate the ETH amount spent
        uint256 _amountSpent = _balanceBeforeCall - _balanceAfterCall;
        // check that amount spent is not more than the maximum price set at deploy time
        require(_amountSpent <= maxPrice, "PartyBuy::buy: can't spend over max price");
        // check that amount spent is not more than
        // the maximum amount the party can spend while paying ETH fee
        require(_amountSpent <= getMaximumSpend(), "PartyBuy::buy: insuffucient funds to pay fee");
        // set partyStatus to WON
        partyStatus = PartyStatus.WON;
        // record totalSpent,
        // send ETH fees to PartyDAO,
        // fractionalize the Token
        // send Token fees to PartyDAO & split proceeds to split recipient
        uint256 _ethFee = _closeSuccessfulParty(_amountSpent);
        // emit Bought event
        emit Bought(msg.sender, _targetContract, _amountSpent, _ethFee, totalContributedToParty);
    }

    // ======== External: Fail =========

    /**
     * @notice If the token couldn't be successfully bought
      * within the specified period of time, move to FAILED state
      * so users can reclaim their funds.
     * @dev Emits a Closed event upon finishing; reverts otherwise.
     * callable by anyone after timeoutAt
     */
    function closeParty() external {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBuy::closeParty: party not active"
        );
        require(timeoutAt <= block.timestamp, "PartyBuy::closeParty: party has not timed out");
        require(_getOwner() != address(this), "PartyBuy::closeParty: contract owns token");
        // set partyStatus to LOST
        partyStatus = PartyStatus.LOST;
        // emit Closed event
        emit Closed();
    }

    // ============ Internal ============

    /**
    * @notice Calculate ETH fee for PartyDAO
    * NOTE: Remove this fee causes a critical vulnerability
    * allowing anyone to exploit a PartyBuy via price manipulation.
    * See Security Review in README for more info.
    * @return _maxContributions the maximum amount that can be contributed to the party
    */
    function getMaximumContributions() public view returns (uint256 _maxContributions) {
        uint256 _price = maxPrice;
        _maxContributions = _price + _getEthFee(_price);
    }
}
