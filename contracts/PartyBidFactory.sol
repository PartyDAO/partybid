// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {PartyBidProxy} from "./PartyBidProxy.sol";
import {PartyBidLogic} from "./PartyBidLogic.sol";
import {ResellerWhitelist} from "./ResellerWhitelist.sol";

/**
 * @title PartyBid Factory
 * @author Anna Carroll
 * forked from MirrorXYZ CrowdfundFactory https://github.com/mirror-xyz/crowdfund/blob/main/contracts/CrowdfundFactory.sol
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
        string name,
        string symbol
    );

    //======== Immutable storage =========

    address public immutable partyDAOMultisig;
    address public immutable logic;
    address public immutable resellerWhitelist;

    //======== Constructor =========

    constructor(address _partyDAOMultisig) {
        partyDAOMultisig = _partyDAOMultisig;
        // deploy logic contract
        logic = address(new PartyBidLogic());
        // deploy and configure whitelist
        ResellerWhitelist _whiteList = new ResellerWhitelist();
        _whiteList.updateWhitelistForAll(_partyDAOMultisig, true);
        _whiteList.transferOwnership(_partyDAOMultisig);
        resellerWhitelist = address(_whiteList);
    }

    //======== Deploy function =========

    function startParty(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        uint256 _quorumPercent,
        string memory _name,
        string memory _symbol
    ) external returns (address partyBidProxy) {
        partyBidProxy = address(
            new PartyBidProxy(
                logic,
                partyDAOMultisig,
                resellerWhitelist,
                _marketWrapper,
                _nftContract,
                _tokenId,
                _auctionId,
                _quorumPercent,
                _name,
                _symbol
            )
        );

        emit PartyBidDeployed(
            partyBidProxy,
            msg.sender,
            _nftContract,
            _tokenId,
            _marketWrapper,
            _auctionId,
            _name,
            _symbol
        );
    }
}
