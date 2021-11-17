// contracts/token/ERC721/IERC721Creator.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

/**
 * @title IERC721 Non-Fungible Token Creator basic interface
 */
abstract contract IERC721Creator {
    /**
     * @dev Gets the creator of the token
     * @param _tokenId uint256 ID of the token
     * @return address of the creator
     */
    function tokenCreator(uint256 _tokenId)
        public
        view
        virtual
        returns (address payable);

    function calcIERC721CreatorInterfaceId() public pure returns (bytes4) {
        return this.tokenCreator.selector;
    }
}
