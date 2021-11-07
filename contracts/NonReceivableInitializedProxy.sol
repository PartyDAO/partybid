// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

/**
 * @title NonReceivableInitializedProxy
 * @author Anna Carroll
 */
contract NonReceivableInitializedProxy {
    // address of logic contract
    address public immutable logic;

    // ======== Constructor =========

    constructor(
        address _logic,
        bytes memory _initializationCalldata
    ) {
        logic = _logic;
        // Delegatecall into the logic contract, supplying initialization calldata
        (bool _ok, bytes memory returnData) =
            _logic.delegatecall(_initializationCalldata);
        // Revert if delegatecall to implementation reverts
        require(_ok, string(returnData));
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
}
