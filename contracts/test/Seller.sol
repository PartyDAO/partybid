// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract Seller {
    function sell(uint256 offer, uint256 tokenId, address nftContract) external payable {
        require(msg.value == offer, "must send offer amt");
        IERC721Metadata(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
    }
}
