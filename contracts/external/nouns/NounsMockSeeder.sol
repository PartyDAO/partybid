// SPDX-License-Identifier: GPL-3.0

/// @title The NounsToken mock seed generator

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

import { INounsSeeder } from './interfaces/INounsSeeder.sol';
import { INounsDescriptor } from './interfaces/INounsDescriptor.sol';

contract NounsMockSeeder is INounsSeeder {
    /**
     * @notice Generate a mock Noun seed.
     */
    function generateSeed(uint256 /* nounId */, INounsDescriptor /* descriptor */) external pure override returns (Seed memory) {
        return Seed({
            background: 0,
            body: 0,
            accessory: 0,
            head: 0,
            glasses: 0
        });
    }
}
