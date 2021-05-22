// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IERC721 {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
