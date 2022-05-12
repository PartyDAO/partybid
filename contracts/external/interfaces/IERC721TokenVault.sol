//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ISettings} from "./IFractionalSettings.sol";

enum TokenState { inactive, live, ended, redeemed }
interface IERC721TokenVault {
    /// @notice the ERC721 token address of the vault's token
    function token() external view returns(address);

    /// @notice the ERC721 token ID of the vault's token
    function id() external view returns(uint256);

    /// @notice the ERC721 totalSupply
    function totalSupply() external view returns(uint256);

    /// @notice the unix timestamp end time of the token auction
    function auctionEnd() external view returns(uint256);

    /// @notice the current price of the token during an auction
    function livePrice() external view returns(uint256);

    /// @notice the current user winning the token auction
    function winning() external view returns(address payable);

    function auctionState() external view returns(TokenState);

    function settings() external view returns(ISettings);

    /// @notice a boolean to indicate if the vault has closed
    /// @dev is not used in Fractional's ERC721TokenVault but it is declared.
    function vaultClosed() external view returns(bool);

    /// @notice the number of ownership tokens voting on the reserve price at any given time
    function votingTokens() external view returns(uint256);

    function reservePrice() external view returns(uint256);

    /// @notice kick off an auction. Must send reservePrice in ETH
    function start() external payable;

    /// @notice an external function to bid on purchasing the vaults NFT. The msg.value is the bid amount
    function bid() external payable;

    /// @notice an external function to end an auction after the timer has run out
    function end() external;
}