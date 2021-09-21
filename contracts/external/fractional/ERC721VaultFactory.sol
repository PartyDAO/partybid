//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OpenZeppelin/access/Ownable.sol";
import "./OpenZeppelin/utils/Pausable.sol";

import "./OpenZeppelin/token/ERC721/ERC721.sol";
import "./OpenZeppelin/token/ERC721/ERC721Holder.sol";

import {InitializedProxy} from "../../InitializedProxy.sol";
import "./Settings.sol";
import "./ERC721TokenVault.sol";

import "hardhat/console.sol";

contract ERC721VaultFactory is Ownable, Pausable {
  /// @notice the number of ERC721 vaults
  uint256 public vaultCount;

  /// @notice the mapping of vault number to vault contract
  mapping(uint256 => address) public vaults;

  /// @notice a settings contract controlled by governance
  address public immutable settings;
  /// @notice the TokenVault logic contract
  address public immutable logic;

  address public immutable weth;

  event Mint(address indexed token, uint256 id, uint256 price, address vault, uint256 vaultId);

  constructor(address _settings, address _weth) {
    settings = _settings;
    logic = address(new TokenVault(_settings, _weth));
    weth = _weth;
  }

  /// @notice the function to mint a new vault
  /// @param _name the desired name of the vault
  /// @param _symbol the desired sumbol of the vault
  /// @param _token the ERC721 token address fo the NFT
  /// @param _id the uint256 ID of the token
  /// @param _listPrice the initial price of the NFT
  /// @return the ID of the vault
  function mint(string memory _name, string memory _symbol, address _token, uint256 _id, uint256 _supply, uint256 _listPrice, uint256 _fee) external whenNotPaused returns(uint256) {
    bytes memory _initializationCalldata =
    abi.encodeWithSignature(
      "initialize(address,address,uint256,uint256,uint256,uint256,string,string)",
      msg.sender,
      _token,
      _id,
      _supply,
      _listPrice,
      _fee,
      _name,
      _symbol
    );

    address vault = address(
      new InitializedProxy(
        logic,
        _initializationCalldata
      )
    );
    console.log("Factory at %s is initializing vault with id %s at %s", address(this), vaultCount, vault);

    emit Mint(_token, _id, _listPrice, vault, vaultCount);

    IERC721(_token).safeTransferFrom(msg.sender, vault, _id);

    vaults[vaultCount] = vault;
    vaultCount++;

    return vaultCount - 1;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

}
