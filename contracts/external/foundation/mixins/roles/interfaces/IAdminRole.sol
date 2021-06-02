// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

/**
 * @notice Interface for AdminRole which wraps the default admin role from
 * OpenZeppelin's AccessControl for easy integration.
 */
interface IAdminRole {
    function isAdmin(address account) external view returns (bool);
}
