// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "./interfaces/IOperatorRole.sol";

import "../FoundationTreasuryNode.sol";

/**
 * @notice Allows a contract to leverage the operator role defined by the Foundation treasury.
 */
abstract contract FoundationOperatorRole is FoundationTreasuryNode {
    // This file uses 0 data slots (other than what's included via FoundationTreasuryNode)

    function _isFoundationOperator() internal view returns (bool) {
        return IOperatorRole(getFoundationTreasury()).isOperator(msg.sender);
    }
}