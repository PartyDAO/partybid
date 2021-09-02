// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./OpenZeppelin/token/ERC721/IERC721.sol";
import "./OpenZeppelin/token/ERC721/IERC721Metadata.sol";
import "./OpenZeppelin/token/ERC721/IERC721Receiver.sol";
import "./OpenZeppelin/introspection/ERC165.sol";
import "./OpenZeppelin/utils/Strings.sol";

contract FNFT is ERC165, IERC721, IERC721Metadata {
    using Strings for uint256;

    uint256 private _count;
    mapping (address => uint256) private _ownerToToken;
    mapping (uint256 => address) private _tokenOwners;

    string public override name;
    string public override symbol;
    address public immutable vault;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI = "https://uri.fractional.art/";

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
        vault = msg.sender;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    modifier onlyVault() {
        require(msg.sender == vault);
        _;
    }

    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _ownerToToken[owner] == 0 ? 0 : 1;
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return _tokenOwners[tokenId];
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    function baseURI() public view virtual returns (string memory) {
        return _baseURI;
    }

    /// unsupported functions

    function approve(address to, uint256 tokenId) public virtual override {
        require(true == false);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        return address(0);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(true == false);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return false;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(true == false);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(true == false);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(true == false);
    }

    /// supported functions

    function mint(address to) external onlyVault {
        _count++;
        _mint(to, _count);
    }

    function burn(address from) external onlyVault {
        _burn(from);
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _tokenOwners[tokenId] != address(0);
    }

    function _mint(address to, uint256 tokenId) internal virtual {
        _ownerToToken[to] = tokenId;
        _tokenOwners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(address from) internal virtual {
        uint256 tokenId = _ownerToToken[from];
        _ownerToToken[from] = 0;
        _tokenOwners[tokenId] = address(0);
        emit Transfer(from, address(0), tokenId);
    }
}