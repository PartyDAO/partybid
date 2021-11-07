// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {InitializedProxy} from "./InitializedProxy.sol";
import {PartyBid} from "./PartyBid.sol";

/**
 * @title PartyBid Factory
 * @author Anna Carroll
 *
 * WARNING: A malicious MarketWrapper contract could be used to steal user funds;
 * A poorly implemented MarketWrapper contract could permanently lose access to the NFT.
 * When deploying a PartyBid, exercise extreme caution.
 * Only use MarketWrapper contracts that have been audited and tested.
 */
contract PartyBidFactory {
    //======== Events ========

    event PartyBidDeployed(
        address partyBidProxy,
        address creator,
        address nftContract,
        uint256 tokenId,
        address marketWrapper,
        uint256 auctionId,
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
        address _logicMarketWrapper,
        address _logicNftContract,
        uint256 _logicTokenId,
        uint256 _logicAuctionId
    ) {
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = _tokenVaultFactory;
        weth = _weth;
        // deploy logic contract
        PartyBid _logicContract = new PartyBid(_partyDAOMultisig, _tokenVaultFactory, _weth);
        // initialize logic contract
        _logicContract.initialize(
            _logicMarketWrapper,
            _logicNftContract,
            _logicTokenId,
            _logicAuctionId,
            address(0),
            0,
            "PartyBid",
            "BID"
        );
        // store logic contract address
        logic = address(_logicContract);
    }

    //======== Deploy function =========

    function startParty(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        address _splitRecipient,
        uint256 _splitBasisPoints,
        string memory _name,
        string memory _symbol
    ) external returns (address partyBidProxy) {
        bytes memory _initializationCalldata =
            abi.encodeWithSignature(
                "initialize(address,address,uint256,uint256,address,uint256,string,string)",
                _marketWrapper,
                _nftContract,
                _tokenId,
                _auctionId,
                _splitRecipient,
                _splitBasisPoints,
                _name,
                _symbol
            );

        partyBidProxy = address(
            new InitializedProxy(
                logic,
                _initializationCalldata
            )
        );

        deployedAt[partyBidProxy] = block.number;

        emit PartyBidDeployed(
            partyBidProxy,
            msg.sender,
            _nftContract,
            _tokenId,
            _marketWrapper,
            _auctionId,
            _splitRecipient,
            _splitBasisPoints,
            _name,
            _symbol
        );
    }
}
