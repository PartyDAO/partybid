// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

contract PayableContract {
    fallback() external payable {} // solhint-disable-line no-empty-blocks

    receive() external payable {} // solhint-disable-line no-empty-blocks
}
