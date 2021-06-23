// SPDX-License-Identifier: MIT

/**
 * NOTE: This file is a clone of the OpenZeppelin ERC721Burnable.sol contract. It was forked from https://github.com/OpenZeppelin/openzeppelin-contracts
 * at commit 1ada3b633e5bfd9d4ffe0207d64773a11f5a7c40
 *
 * It was cloned in order to ensure it imported from the cloned ERC721.sol file. No other modifications have been made.
 */

pragma solidity 0.6.8;

import "@openzeppelin/contracts2/GSN/Context.sol";
import "./ERC721.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be irreversibly burned (destroyed).
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        _burn(tokenId);
    }
}
