// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

/**
 * @title PartyBid Proxy
 * @author Anna Carroll
 */
contract PartyBidProxy {
    // address of PartyBid logic contract
    address public immutable logic;

    // ======== Constructor =========

    constructor(
        address _logic,
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        string memory _name,
        string memory _symbol
    ) {
        logic = _logic;
        bytes memory _initializationCalldata =
            abi.encodeWithSignature(
                "initialize(address,address,uint256,uint256,string,string)",
                _marketWrapper,
                _nftContract,
                _tokenId,
                _auctionId,
                _name,
                _symbol
            );
        // Delegatecall into the logic contract, supplying initialization calldata.
        (bool _ok, ) = _logic.delegatecall(_initializationCalldata);
        // Revert and include revert data if delegatecall to implementation reverts.
        if (!_ok) {
            assembly {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }
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
