// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import {PayableContract} from "./PayableContract.sol";

contract MockFoundationTreasury is PayableContract {
    function isAdmin(address) external pure returns (bool) {
        return true;
    }
}
