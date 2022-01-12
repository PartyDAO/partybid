// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract TestERC721 is ERC721Burnable {
    constructor() ERC721("TestNFT", "tNFT") {} // solhint-disable-line no-empty-blocks

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function destruct() public {
        selfdestruct(payable(address(0)));
    }
}
