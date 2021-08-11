// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract TestERC721 is ERC721Burnable {
    uint256 private _currentTokenId;

    constructor(uint256 currentTokenId) ERC721("TestNFT", "tNFT") {
        _currentTokenId = currentTokenId;
    }

    function mintTo(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function mint() external returns (uint256) {
        uint256 tokenId = _currentTokenId++;

        _mint(msg.sender, tokenId);
        return tokenId;
    }

    function destruct() public {
        selfdestruct(payable(address(0)));
    }
}
