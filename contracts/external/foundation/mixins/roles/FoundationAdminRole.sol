// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "./interfaces/IAdminRole.sol";

import "../FoundationTreasuryNode.sol";

/**
 * @notice Allows a contract to leverage an admin role defined by the Foundation contract.
 */
abstract contract FoundationAdminRole is FoundationTreasuryNode {
    // This file uses 0 data slots (other than what's included via FoundationTreasuryNode)

    modifier onlyFoundationAdmin() {
        require(
            IAdminRole(getFoundationTreasury()).isAdmin(msg.sender),
            "FoundationAdminRole: caller does not have the Admin role"
        );
        _;
    }
}
