//SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IERC721TokenVault {  
  // Returns value corresponding to the enum: State { inactive, live, ended, redeemed }
  function auctionState() external view returns (uint8);

  function auctionEnd() external view returns (uint256);

  function token() external view returns (address);

  function id() external view returns (uint256);

  function reservePrice() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function votingTokens() external view returns (uint256);

  function settings() external view returns (address);

  function livePrice() external view returns (uint256);

  function winning() external view returns (address);

  function end() external;
}