/*
                   ___                    _       _  _    ___     ___     ___
                  | _ \  __ _      _ _   | |_    | || |  |   \   /   \   / _ \
   ~~~~ ____      |  _/ / _` |    | '_|  |  _|    \_, |  | |) |  | - |  | (_) |
  Y_,___|[]|     _|_|_  \__,_|   _|_|_   _\__|   _|__/   |___/   |_|_|   \___/
 {|_|_|_|[]|_,__| """ |_|"""""|_|"""""|_|"""""|_| """"|_|"""""|_|"""""|_|"""""|
//oo---OO=OO".  `-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'"`-0-0-'

Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports: External Contracts & Contract Interfaces ============
import {Party} from "./Party.sol";
import {Structs} from "./Structs.sol";
import {IAllowList} from "./IAllowList.sol";

contract PartyBuy is Party {
    // partyStatus Transitions:
    //   (1) PartyStatus.ACTIVE on deploy
    //   (2) PartyStatus.WON after successful buy()
    //   (3) PartyStatus.LOST after successful expire()

    // ============ Internal Constants ============

    // PartyBuy version 1
    uint16 public constant VERSION = 1;

    // ============ Immutables ============

    IAllowList public immutable allowList;

    // ============ Public Not-Mutated Storage ============

    // the timestamp at which the Party is no longer active
    uint256 public expiresAt;
    // the maximum price that the party is willing to
    // spend on the token
    // NOTE: the party can accept *UP TO* 102.5% of maxPrice in total,
    // and will not accept more contributions after this
    uint256 public maxPrice;

    // ============ Events ============

    // emitted when the token is successfully bought
    event Bought(
        address triggeredBy,
        address targetAddress,
        uint256 ethSpent,
        uint256 ethFeePaid,
        uint256 totalContributed
    );

    // emitted if the Party fails to buy the token before expiresAt
    // and someone expires the Party so folks can reclaim ETH
    event Expired(address triggeredBy);

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth,
        address _allowList
    ) Party(_partyDAOMultisig, _tokenVaultFactory, _weth) {
        allowList = IAllowList(_allowList);
    }

    // ======== Initializer =========

    function initialize(
        address _nftContract,
        uint256 _tokenId,
        uint256 _maxPrice,
        uint256 _secondsToTimeout,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol
    ) external initializer {
        // validate maxPrice
        require(
            _maxPrice > 0,
            "PartyBuy::initialize: must set price higher than 0"
        );
        // initialize & validate shared Party variables
        __Party_init(_nftContract, _split, _tokenGate, _name, _symbol);
        // verify token exists
        tokenId = _tokenId;
        require(
            _getOwner() != address(0),
            "PartyBuy::initialize: NFT getOwner failed"
        );
        // set PartyBuy-specific state variables
        expiresAt = block.timestamp + _secondsToTimeout;
        maxPrice = _maxPrice;
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
        require(
            totalContributedToParty + msg.value <= getMaximumContributions(),
            "PartyBuy::contribute: cannot contribute more than max"
        );
        // continue with shared _contribute flow
        _contribute();
    }

    // ======== External: Buy =========

    /**
     * @notice Buy the token by calling targetContract with calldata supplying value
     * @dev Emits a Bought event upon success; reverts otherwise. callable by anyone
     */
    function buy(
        uint256 _value,
        address _targetContract,
        bytes calldata _calldata
    ) external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBuy::buy: party not active"
        );
        // ensure the target contract is on allow list
        require(
            allowList.allowed(_targetContract),
            "PartyBuy::buy: targetContract not on AllowList"
        );
        // check that value is not zero (else, token will be burned in TokenVault)
        require(_value > 0, "PartyBuy::buy: can't spend zero");
        // check that value is not more than the maximum price set at deploy time
        require(
            _value <= maxPrice,
            "PartyBuy::buy: can't spend over max price"
        );
        // check that value is not more than
        // the maximum amount the party can spend while paying ETH fee
        require(
            _value <= getMaximumSpend(),
            "PartyBuy::buy: insuffucient funds to buy token plus fee"
        );
        // require that the NFT is NOT owned by the Party
        require(
            _getOwner() != address(this),
            "PartyBuy::buy: own token before call"
        );
        // execute the calldata on the target contract
        (bool _success, bytes memory _returnData) = address(_targetContract)
            .call{value: _value}(_calldata);
        // require that the external call succeeded
        require(_success, string(_returnData));
        // require that the NFT is owned by the Party
        require(
            _getOwner() == address(this),
            "PartyBuy::buy: failed to buy token"
        );
        // set partyStatus to WON
        partyStatus = PartyStatus.WON;
        // record totalSpent,
        // send ETH fees to PartyDAO,
        // fractionalize the Token
        // send Token fees to PartyDAO & split proceeds to split recipient
        uint256 _ethFee = _closeSuccessfulParty(_value);
        // emit Bought event
        emit Bought(
            msg.sender,
            _targetContract,
            _value,
            _ethFee,
            totalContributedToParty
        );
    }

    // ======== External: Fail =========

    /**
     * @notice If the token couldn't be successfully bought
     * within the specified period of time, move to FAILED state
     * so users can reclaim their funds.
     * @dev Emits a Expired event upon finishing; reverts otherwise.
     * callable by anyone after expiresAt
     */
    function expire() external nonReentrant {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "PartyBuy::expire: party not active"
        );
        require(
            expiresAt <= block.timestamp,
            "PartyBuy::expire: party has not timed out"
        );
        // set partyStatus to LOST
        partyStatus = PartyStatus.LOST;
        // emit Expired event
        emit Expired(msg.sender);
    }

    // ============ Internal ============

    /**
     * @notice Get the maximum amount that can be contributed to the Party
     * @return _maxContributions the maximum amount that can be contributed to the party
     */
    function getMaximumContributions()
        public
        view
        returns (uint256 _maxContributions)
    {
        uint256 _price = maxPrice;
        _maxContributions = _price + _getEthFee(_price);
    }
}
