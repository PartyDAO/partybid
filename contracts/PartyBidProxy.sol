// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";

// ============ Internal Imports ============
import {PartyBidStorage} from "./PartyBidStorage.sol";
import {IMarketWrapper} from "./interfaces/IMarketWrapper.sol";
import {ResellerWhitelist} from "./ResellerWhitelist.sol";

/**
 * @title PartyBid Proxy
 * @author Anna Carroll
 * forked from MirrorXYZ CrowdfundProxy https://github.com/mirror-xyz/crowdfund/blob/main/contracts/CrowdfundProxy.sol
 */
contract PartyBidProxy is PartyBidStorage {
    // ======== Constructor =========

    constructor(
        address _WETH,
        address _logic,
        address _partyDAOMultisig,
        address _resellerWhitelist,
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        uint256 _quorumPercent,
        string memory _name,
        string memory _symbol
    ) {
        WETH = IWETH(_WETH);
        logic = _logic;
        // set storage variables
        partyDAOMultisig = _partyDAOMultisig;
        resellerWhitelist = ResellerWhitelist(_resellerWhitelist);
        marketWrapper = IMarketWrapper(_marketWrapper);
        nftContract = IERC721Metadata(_nftContract);
        auctionId = _auctionId;
        tokenId = _tokenId;
        quorumPercent = _quorumPercent;
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
            "auctionId doesn't match token"
        );
        // validate quorum percent
        require(0 < _quorumPercent && _quorumPercent <= 100, "!valid quorum");
    }

    // ======== Fallback =========

    fallback() external payable {
        address _impl = logic;
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), _impl, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)

            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }

    // ======== Receive =========

    receive() external payable {} // solhint-disable-line no-empty-blocks
}
