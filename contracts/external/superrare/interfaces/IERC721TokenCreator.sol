// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

interface IERC721TokenCreator {
    function tokenCreator(address _contractAddress, uint256 _tokenId)
        external
        view
        returns (address payable);
}
