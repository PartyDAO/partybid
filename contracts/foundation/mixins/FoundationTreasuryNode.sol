// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

/**
 * @notice A mixin that stores a reference to the Foundation treasury contract.
 */
abstract contract FoundationTreasuryNode is Initializable {
    using AddressUpgradeable for address payable;

    address payable private treasury;

    /**
     * @dev Called once after the initial deployment to set the Foundation treasury address.
     */
    function _initializeFoundationTreasuryNode(address payable _treasury)
        internal
        initializer
    {
        require(
            _treasury.isContract(),
            "FoundationTreasuryNode: Address is not a contract"
        );
        treasury = _treasury;
    }

    /**
     * @notice Returns the address of the Foundation treasury.
     */
    function getFoundationTreasury() public view returns (address payable) {
        return treasury;
    }

    // `______gap` is added to each mixin to allow adding new data slots or additional mixins in an upgrade-safe way.
    uint256[2000] private __gap;
}
