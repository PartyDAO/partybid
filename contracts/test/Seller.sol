// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {PartyBuy} from "../PartyBuy.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract Seller {
    function sell(
        uint256 offer,
        uint256 tokenId,
        address nftContract
    ) external payable {
        require(msg.value == offer, "must send offer amt");
        IERC721Metadata(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
    }

    function sellAndReenter(
        uint256 offer,
        uint256 tokenId,
        address nftContract
    ) external payable {
        require(msg.value == offer, "must send offer amt");
        IERC721Metadata(nftContract).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        (bool _success, bytes memory _returnData) = address(msg.sender).call{
            value: offer
        }(
            abi.encodeWithSelector(
                PartyBuy.buy.selector,
                offer,
                address(this),
                abi.encodeWithSelector(
                    Seller.fakeSell.selector,
                    offer,
                    tokenId,
                    nftContract
                )
            )
        );
        require(_success, "re-enter failed");
    }

    function revertSell(
        uint256 offer,
        uint256 tokenId,
        address nftContract
    ) external payable {
        require(false, "muahahaha");
    }

    function fakeSell(
        uint256 offer,
        uint256 tokenId,
        address nftContract
    ) external payable {
        require(msg.value == offer, "must send offer amt");
    }
}
