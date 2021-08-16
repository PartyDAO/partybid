// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns Mock NFT descriptor

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.5;

import { INounsDescriptor } from './interfaces/INounsDescriptor.sol';
import { INounsSeeder } from './interfaces/INounsSeeder.sol';

contract NounsMockDescriptor is INounsDescriptor {
    /**
     * @notice Given a token ID and seed, construct a mock token URI for a Nouns DAO noun.
     */
    function tokenURI(uint256 /* tokenId */, INounsSeeder.Seed memory /* seed */) external pure override returns (string memory) {
        return string('');
    }

    /**
     * @notice Given a token ID and seed, construct a base64 encoded data URI for an official Nouns DAO noun.
     */
    function dataURI(uint256 /* tokenId */, INounsSeeder.Seed memory /* seed */) public pure override returns (string memory) {
        return string('');
    }
}
