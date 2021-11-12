// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

/**
 * @title IAllowList
 * @author Anna Carroll
 */
interface IAllowList {
    function allowed(address _addr) external returns (bool _bool);
}
