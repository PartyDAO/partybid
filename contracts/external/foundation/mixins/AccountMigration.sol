// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0x1bed4009d57fcdc068a489a153601d63ce4b04b2#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "@openzeppelin/contracts2/cryptography/ECDSA.sol";
import "@openzeppelin/contracts2/utils/Address.sol";
import "@openzeppelin/contracts2/utils/Strings.sol";
import "./roles/FoundationOperatorRole.sol";
import "../interfaces/IERC1271.sol";

/**
 * @notice Checks for a valid signature authorizing the migration of an account to a new address.
 * @dev This is shared by both the FNDNFT721 and FNDNFTMarket, and the same signature authorizes both.
 */
abstract contract AccountMigration is FoundationOperatorRole {
    // From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/cryptography
    function _isValidSignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) private view returns (bool) {
        if (Address.isContract(signer)) {
            try IERC1271(signer).isValidSignature(hash, signature) returns (bytes4 magicValue) {
                return magicValue == IERC1271(signer).isValidSignature.selector;
            } catch {
                return false;
            }
        } else {
            return ECDSA.recover(hash, signature) == signer;
        }
    }

    // From https://ethereum.stackexchange.com/questions/8346/convert-address-to-string
    function _toAsciiString(address x) private pure returns (string memory) {
        bytes memory s = new bytes(42);
        s[0] = "0";
        s[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint256(uint160(x)) / (2**(8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i + 2] = _char(hi);
            s[2 * i + 3] = _char(lo);
        }
        return string(s);
    }

    function _char(bytes1 b) private pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.1.0/contracts/utils/cryptography/ECDSA.sol
    // Modified to accept messages (instead of the message hash)
    function _toEthSignedMessage(bytes memory message) private pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(message.length), message));
    }

    /**
     * @dev Confirms the msg.sender is a Foundation operator and that the signature provided is valid.
     * @param signature Message `I authorize Foundation to migrate my account to ${newAccount.address.toLowerCase()}`
     * signed by the original account.
     */
    modifier onlyAuthorizedAccountMigration(
        address originalAddress,
        address newAddress,
        bytes memory signature
    ) {
        require(_isFoundationOperator(), "AccountMigration: Caller is not an operator");
        bytes32 hash =
        _toEthSignedMessage(
            abi.encodePacked("I authorize Foundation to migrate my account to ", _toAsciiString(newAddress))
        );
        require(
            _isValidSignatureNow(originalAddress, hash, signature),
            "AccountMigration: Signature must be from the original account"
        );
        _;
    }
}