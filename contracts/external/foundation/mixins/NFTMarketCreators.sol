// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "../interfaces/IFNDNFT721.sol";

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @notice A mixin for associating creators to NFTs.
 * @dev In the future this may store creators directly in order to support NFTs created on a different platform.
 */
abstract contract NFTMarketCreators is
    ReentrancyGuardUpgradeable // Adding this unused mixin to help with linearization
{
    /**
     * @dev If the creator is not available then 0x0 is returned. Downstream this indicates that the creator
     * fee should be sent to the current seller instead.
     * This may apply when selling NFTs that were not minted on Foundation.
     */
    function getCreator(address nftContract, uint256 tokenId)
        internal
        view
        returns (address payable)
    {
        try IFNDNFT721(nftContract).tokenCreator(tokenId) returns (
            address payable creator
        ) {
            return creator;
        } catch {
            return address(0);
        }
    }

    // 500 slots were added via the new SendValueWithFallbackWithdraw mixin
    uint256[500] private ______gap;
}
