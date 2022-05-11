//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISettings {
    function minBidIncrease() external view returns(uint256);

    function minVotePercentage() external view returns(uint256);
}