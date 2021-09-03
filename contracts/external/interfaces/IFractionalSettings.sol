//SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

interface IFractionalSettings {
    function minBidIncrease() external view returns(uint256);

    function minVotePercentage() external view returns(uint256);
}