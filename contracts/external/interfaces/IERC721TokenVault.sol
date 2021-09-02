//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IWETH.sol";
import "../fractional/OpenZeppelin/math/Math.sol";
import "../fractional/OpenZeppelin/token/ERC20/ERC20.sol";
import "../fractional/OpenZeppelin/token/ERC721/ERC721.sol";
import "../fractional/OpenZeppelin/token/ERC721/ERC721Holder.sol";

import "../fractional/Settings.sol";
import "../fractional/FNFT.sol";

import "../fractional/OpenZeppelin/upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "../fractional/OpenZeppelin/upgradeable/token/ERC20/ERC20Upgradeable.sol";

// contract TokenVault is ERC20Upgradeable, ERC721HolderUpgradeable {
contract TokenVault is IERC20, IERC721 {
    using Address for address;

    /// -----------------------------------
    /// -------- BASIC INFORMATION --------
    /// -----------------------------------

    /// @notice weth address
    address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// -----------------------------------
    /// -------- TOKEN INFORMATION --------
    /// -----------------------------------

    /// @notice the ERC721 token address of the vault's token
    address public token;

    /// @notice the ERC721 token ID of the vault's token
    uint256 public id;

    /// -------------------------------------
    /// -------- AUCTION INFORMATION --------
    /// -------------------------------------

    /// @notice the unix timestamp end time of the token auction
    uint256 public auctionEnd;

    /// @notice the length of auctions
    uint256 public auctionLength;

    /// @notice reservePrice * votingTokens
    uint256 public reserveTotal;

    /// @notice the current price of the token during an auction
    uint256 public livePrice;

    /// @notice the current user winning the token auction
    address payable public winning;

    enum State { inactive, live, ended, redeemed }

    State public auctionState;

    /// -----------------------------------
    /// -------- VAULT INFORMATION --------
    /// -----------------------------------

    /// @notice the governance contract which gets paid in ETH
    address public immutable settings;

    /// @notice the address who initially deposited the NFT
    address public curator;

    /// @notice the AUM fee paid to the curator yearly. 3 decimals. ie. 100 = 10%
    uint256 public fee;

    /// @notice the last timestamp where fees were claimed
    uint256 public lastClaimed;

    /// @notice a boolean to indicate if the vault has closed
    bool public vaultClosed;

    /// @notice the number of ownership tokens voting on the reserve price at any given time
    uint256 public votingTokens;

    /// @notice a mapping of users to their desired token price
    mapping(address => uint256) public userPrices;

    /// @notice a non transferable NFT
    FNFT public nft;

    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------

    /// @notice An event emitted when a user updates their price
    event PriceUpdate(address indexed user, uint price);

    /// @notice An event emitted when an auction starts
    event Start(address indexed buyer, uint price);

    /// @notice An event emitted when a bid is made
    event Bid(address indexed buyer, uint price);

    /// @notice An event emitted when an auction is won
    event Won(address indexed buyer, uint price);

    /// @notice An event emitted when someone redeems all tokens for the NFT
    event Redeem(address indexed redeemer);

    /// @notice An event emitted when someone cashes in ERC20 tokens for ETH from an ERC721 token sale
    event Cash(address indexed owner, uint256 shares);

    function initialize(address _curator, address _token, uint256 _id, uint256 _supply, uint256 _listPrice, uint256 _fee, string memory _name, string memory _symbol) external;


    /// --------------------------------
    /// -------- VIEW FUNCTIONS --------
    /// --------------------------------

    function reservePrice() public view returns(uint256);

    /// -------------------------------
    /// -------- GOV FUNCTIONS --------
    /// -------------------------------

    /// @notice allow governance to boot a bad actor curator
    /// @param _curator the new curator
    function kickCurator(address _curator) external;

    /// @notice allow governance to remove bad reserve prices
    function removeReserve(address _user) external;

    /// -----------------------------------
    /// -------- CURATOR FUNCTIONS --------
    /// -----------------------------------

    /// @notice allow curator to update the curator address
    /// @param _curator the new curator
    function updateCurator(address _curator) external;

    /// @notice allow curator to update the auction length
    /// @param _length the new base price
    function updateAuctionLength(uint256 _length) external;

    /// @notice allow the curator to change their fee
    /// @param _fee the new fee
    function updateFee(uint256 _fee) external;

    /// @notice external function to claim fees for the curator and governance
    function claimFees() external;

    /// --------------------------------
    /// -------- CORE FUNCTIONS --------
    /// --------------------------------

    /// @notice a function for an end user to update their desired sale price
    /// @param _new the desired price in ETH
    function updateUserPrice(uint256 _new) external;

    /// @notice kick off an auction. Must send reservePrice in ETH
    function start() external payable;

    /// @notice an external function to bid on purchasing the vaults NFT. The msg.value is the bid amount
    function bid() external payable;

    /// @notice an external function to end an auction after the timer has run out
    function end() external;

    /// @notice an external function to burn all ERC20 tokens to receive the ERC721 token
    function redeem() external {}

    /// @notice an external function to burn ERC20 tokens to receive ETH from ERC721 token purchase
    function cash() external;

}