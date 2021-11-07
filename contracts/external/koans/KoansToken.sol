// SPDX-License-Identifier: GPL-3.0

/// @title The Koans ERC-721 token

pragma solidity ^0.8.6;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IKoansToken } from "./interfaces/IKoansToken.sol";
import { ERC721Checkpointable } from "./base/ERC721Checkpointable.sol";
import { ERC721 } from "./base/ERC721.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IProxyRegistry {
    function proxies(address) external view returns (address);
}

contract KoansToken is IKoansToken, Ownable, ERC721Checkpointable {
    // The Founders DAO address.
    address public foundersDAO;

    // An address who has permissions to mint Koans
    address public minter;

    // Whether the minter can be updated
    bool public isMinterLocked;

    // The internal koan ID tracker
    uint256 private _currentKoanId;

    // IPFS content hash of contract-level metadata
    string private _contractURIHash = "QmcYj48J4MGr4ASXqfhsvTTJcDXDNCv2uuYRxKvHMfP2b7";

    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    // Map from tokenIDs to IPFS paths to images/metadata.
    mapping(uint256 => string) public uriPaths;


    // If the initial koan to be awarded to the Founders DAO has been minted.
    bool public initFoundersDAOKoanMinted = false;

    /**
     * @notice Require that the minter has not been locked.
     */
    modifier whenMinterNotLocked() {
        require(!isMinterLocked, "Minter is locked");
        _;
    }

    /**
     * @notice Require that the sender is the Founders DAO.
     */
    modifier onlyFoundersDAO() {
        require(msg.sender == foundersDAO, "Sender is not the Founders DAO");
        _;
    }

    /**
     * @notice Require that the sender is the minter.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "Sender is not the minter");
        _;
    }

    constructor(
        address _foundersDAO,
        address _minter,
        IProxyRegistry _proxyRegistry,
        uint256 currentNounId
    ) public ERC721("Koans", "KOAN") {
        foundersDAO = _foundersDAO;
        minter = _minter;
        proxyRegistry = _proxyRegistry;

        // This is used for testing purposes only and does not exist in the deployed implementation
        _currentKoanId = currentNounId;
    }

    /**
     * @notice Set the _contractURIHash.
     * @dev Only callable by the owner.
     */
    function setContractURIHash(string memory newContractURIHash) external override onlyOwner {
        _contractURIHash = newContractURIHash;
    }

    /**
     * @notice Set the founders DAO.
     * @dev Only callable by the founders DAO.
     */
    function setFoundersDAO(address _foundersDAO) external override onlyFoundersDAO {
        foundersDAO = _foundersDAO;

        emit FoundersDAOUpdated(_foundersDAO);
    }

    /**
     * @notice Set the token minter.
     * @dev Only callable by the owner when not locked.
     */
    function setMinter(address _minter) external override onlyOwner whenMinterNotLocked {
        minter = _minter;

        emit MinterUpdated(_minter);
    }

    /**
     * @notice Lock the minter.
     * @dev This cannot be reversed and is only callable by the owner when not locked.
     */
    function lockMinter() external override onlyOwner whenMinterNotLocked {
        isMinterLocked = true;

        emit MinterLocked();
    }

    function mintFoundersDAOKoan(string memory _foundersDAOMetadataURI) external override onlyFoundersDAO {
        require(!initFoundersDAOKoanMinted, "Already minted initial Koan");
        uint foundersDAOKoanId = _mintTo(foundersDAO, _currentKoanId++);
        uriPaths[foundersDAOKoanId] = _foundersDAOMetadataURI;
        initFoundersDAOKoanMinted = true;
    }

    /**
     * @notice Mint a Koan to the minter.
     * @dev Call _mintTo with the to address(es).
     */
    function mint() public override onlyMinter returns (uint256) {
        return _mintTo(minter, _currentKoanId++);
    }

    /**
     * @notice Burn a Koan. Unlike the deployed Koans token, this function
     * allows any caller to burn a Koan for testing purposes.
     */
    function burn(uint256 tokenId) public override {
        _burn(tokenId);
        emit KoanBurned(tokenId);
    }

    /**
     * @notice Set the metadata URI for a Koan.
     */
    function setMetadataURI(uint256 tokenId, string memory metadataURI) public override onlyMinter {
        require(_exists(tokenId), "nonexistent token.");
        require(bytes(uriPaths[tokenId]).length == 0, "URI is already set.");
        uriPaths[tokenId] = metadataURI;
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token.");
        return uriPaths[tokenId];
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override(IERC721, ERC721) returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice The IPFS URI of contract-level metadata.
     */
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked("ipfs://", _contractURIHash));
    }

    /**
     * @notice Mint a Koan with `koanId` to the provided `to` address.
     */
    function _mintTo(address to, uint256 koanId) internal returns (uint256) {
        _mint(owner(), to, koanId);
        emit KoanCreated(koanId);

        return koanId;
    }
}
