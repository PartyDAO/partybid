// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {NonReceivableInitializedProxy} from "./NonReceivableInitializedProxy.sol";
import {CollectionParty} from "./CollectionParty.sol";
import {Structs} from "./Structs.sol";

/**
 * @title CollectionParty Factory
 * @author Anna Carroll
 */
contract CollectionPartyFactory {
    //======== Events ========

    event CollectionPartyDeployed(
        address indexed partyProxy,
        address indexed creator,
        address indexed nftContract,
        uint256 maxPrice,
        uint256 secondsToTimeout,
        address[] deciders,
        address splitRecipient,
        uint256 splitBasisPoints,
        address gatedToken,
        uint256 gatedTokenAmount,
        string name,
        string symbol
    );

    //======== Immutable storage =========

    address public immutable logic;
    address public immutable partyDAOMultisig;
    address public immutable tokenVaultFactory;
    address public immutable weth;

    //======== Mutable storage =========

    // PartyBid proxy => block number deployed at
    mapping(address => uint256) public deployedAt;

    //======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth,
        address _allowList
    ) {
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = _tokenVaultFactory;
        weth = _weth;
        // deploy logic contract
        CollectionParty _logicContract = new CollectionParty(
            _partyDAOMultisig,
            _tokenVaultFactory,
            _weth,
            _allowList
        );
        // store logic contract address
        logic = address(_logicContract);
    }

    //======== Deploy function =========

    function startParty(
        address _nftContract,
        uint256 _maxPrice,
        uint256 _secondsToTimeout,
        address[] calldata _deciders,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol
    ) external returns (address partyProxy) {
        bytes memory _initializationCalldata = abi.encodeWithSelector(
            CollectionParty.initialize.selector,
            _nftContract,
            _maxPrice,
            _secondsToTimeout,
            _deciders,
            _split,
            _tokenGate,
            _name,
            _symbol
        );

        partyProxy = address(
            new NonReceivableInitializedProxy(logic, _initializationCalldata)
        );

        deployedAt[partyProxy] = block.number;

        emit CollectionPartyDeployed(
            partyProxy,
            msg.sender,
            _nftContract,
            _maxPrice,
            _secondsToTimeout,
            _deciders,
            _split.addr,
            _split.amount,
            _tokenGate.addr,
            _tokenGate.amount,
            _name,
            _symbol
        );
    }
}
