// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../access/OwnableUpgradeable.sol";
import "../interfaces/IERC1271Upgradeable.sol";
import "../utils/cryptography/ECDSAUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

contract ERC1271WalletMockUpgradeable is Initializable, OwnableUpgradeable, IERC1271Upgradeable {
    function __ERC1271WalletMock_init(address originalOwner) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC1271WalletMock_init_unchained(originalOwner);
    }

    function __ERC1271WalletMock_init_unchained(address originalOwner) internal initializer {
        transferOwnership(originalOwner);
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view override returns (bytes4 magicValue) {
        return ECDSAUpgradeable.recover(hash, signature) == owner() ? this.isValidSignature.selector : bytes4(0);
    }
    uint256[50] private __gap;
}
