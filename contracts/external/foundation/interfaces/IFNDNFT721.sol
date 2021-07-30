// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0
// solhint-disable

pragma solidity ^0.7.0;

interface IFNDNFT721 {
    function tokenCreator(uint256 tokenId) external view returns (address payable);

    function getTokenCreatorPaymentAddress(uint256 tokenId) external view returns (address payable);
}