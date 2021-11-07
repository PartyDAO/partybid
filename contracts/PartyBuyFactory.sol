// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {InitializedProxy} from "./InitializedProxy.sol";
import {PartyBuy} from "./PartyBuy.sol";

/**
 * @title PartyBuy Factory
 * @author Anna Carroll
 */
contract PartyBuyFactory {
    //======== Events ========

    event PartyBuyDeployed(
        address partyProxy,
        address creator,
        address nftContract,
        uint256 tokenId,
        uint256 maxPrice,
        uint256 secondsToTimeout,
        address splitRecipient,
        uint256 splitBasisPoints,
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
        address _logicNftContract,
        uint256 _logicTokenId
    ) {
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = _tokenVaultFactory;
        weth = _weth;
        // deploy logic contract
        PartyBuy _logicContract = new PartyBuy(_partyDAOMultisig, _tokenVaultFactory, _weth);
        // initialize logic contract
        _logicContract.initialize(
            _logicNftContract,
            _logicTokenId,
            100,
            1,
            address(0),
            0,
            "PartyBuy",
            "BUY"
        );
        // store logic contract address
        logic = address(_logicContract);
    }

    //======== Deploy function =========

    function startParty(
        address _nftContract,
        uint256 _tokenId,
        uint256 _maxPrice,
        uint256 _secondsToTimeout,
        address _splitRecipient,
        uint256 _splitBasisPoints,
        string memory _name,
        string memory _symbol
    ) external returns (address partyBuyProxy) {
        bytes memory _initializationCalldata =
            abi.encodeWithSignature(
            "initialize(address,uint256,uint256,uint256,address,uint256,string,string)",
            _nftContract,
            _tokenId,
            _maxPrice,
            _secondsToTimeout,
            _splitRecipient,
            _splitBasisPoints,
            _name,
            _symbol
        );

        partyBuyProxy = address(
            new InitializedProxy(
                logic,
                _initializationCalldata
            )
        );

        deployedAt[partyBuyProxy] = block.number;

        emit PartyBuyDeployed(
            partyBuyProxy,
            msg.sender,
            _nftContract,
            _tokenId,
            _maxPrice,
            _secondsToTimeout,
            _splitRecipient,
            _splitBasisPoints,
            _name,
            _symbol
        );
    }
}
