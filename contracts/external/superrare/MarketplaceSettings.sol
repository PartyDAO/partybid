// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "./interfaces/old/IMarketplaceSettings.sol";
import "@openzeppelin/contracts2/access/Ownable.sol";
import "@openzeppelin/contracts2/access/AccessControl.sol";
import "@openzeppelin/contracts2/math/SafeMath.sol";

/**
 * @title MarketplaceSettings Settings governing the marketplace fees.
 */
contract MarketplaceSettings is
    Ownable,
    AccessControl,
    IMarketplaceSettings
{
    using SafeMath for uint256;

    /////////////////////////////////////////////////////////////////////////
    // Constants
    /////////////////////////////////////////////////////////////////////////

    bytes32 public constant TOKEN_MARK_ROLE = "TOKEN_MARK_ROLE";

    /////////////////////////////////////////////////////////////////////////
    // State Variables
    /////////////////////////////////////////////////////////////////////////

    // Max wei value within the marketplace
    uint256 private maxValue;

    // Min wei value within the marketplace
    uint256 private minValue;

    // Percentage fee for the marketplace, 3 == 3%
    uint8 private marketplaceFeePercentage;

    // Mapping of ERC721 contract to the primary sale fee. If primary sale fee is 0 for an origin contract then primary sale fee is ignored. 1 == 1%
    mapping(address => uint8) private primarySaleFees;

    // Mapping of ERC721 contract to mapping of token ID to whether the token has been sold before.
    mapping(address => mapping(uint256 => bool)) private soldTokens;

    /////////////////////////////////////////////////////////////////////////
    // Constructor
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Initializes the contract maxValue, minValues, and marketplaceFeePercentage to default settings.
     *      Also, sets the roles for the contract to the owner.
     */
    constructor() {
        maxValue = 2**254; // 2 ^ 254 is max amount, prevents any overflow issues.

        minValue = 1000; // all amounts must be greater than 1000 Wei.

        marketplaceFeePercentage = 3; // 3% marketplace fee on all txs.

        _setupRole(AccessControl.DEFAULT_ADMIN_ROLE, owner());
        grantRole(TOKEN_MARK_ROLE, owner());
    }

    /////////////////////////////////////////////////////////////////////////
    // grantMarketplaceMarkTokenAccess
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Grants a marketplace contract access to marke
     * @param _account address of the account that can perform the token mark role.
     */
    function grantMarketplaceAccess(address _account) external {
        require(
            hasRole(AccessControl.DEFAULT_ADMIN_ROLE, msg.sender),
            "grantMarketplaceAccess::Must be admin to call method"
        );
        grantRole(TOKEN_MARK_ROLE, _account);
    }

    /////////////////////////////////////////////////////////////////////////
    // getMarketplaceMaxValue
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Get the max value to be used with the marketplace.
     * @return uint256 wei value.
     */
    function getMarketplaceMaxValue() external view override returns (uint256) {
        return maxValue;
    }

    /////////////////////////////////////////////////////////////////////////
    // setMarketplaceMaxValue
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Set the maximum value of the marketplace settings.
     * @param _maxValue uint256 maximum wei value.
     */
    function setMarketplaceMaxValue(uint256 _maxValue) external onlyOwner {
        maxValue = _maxValue;
    }

    /////////////////////////////////////////////////////////////////////////
    // getMarketplaceMinValue
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Get the max value to be used with the marketplace.
     * @return uint256 wei value.
     */
    function getMarketplaceMinValue() external view override returns (uint256) {
        return minValue;
    }

    /////////////////////////////////////////////////////////////////////////
    // setMarketplaceMinValue
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Set the minimum value of the marketplace settings.
     * @param _minValue uint256 minimum wei value.
     */
    function setMarketplaceMinValue(uint256 _minValue) external onlyOwner {
        minValue = _minValue;
    }

    /////////////////////////////////////////////////////////////////////////
    // getMarketplaceFeePercentage
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Get the marketplace fee percentage.
     * @return uint8 wei fee.
     */
    function getMarketplaceFeePercentage()
        external
        view
        override
        returns (uint8)
    {
        return marketplaceFeePercentage;
    }

    /////////////////////////////////////////////////////////////////////////
    // setMarketplaceFeePercentage
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Set the marketplace fee percentage.
     * Requirements:
     * - `_percentage` must be <= 100.
     * @param _percentage uint8 percentage fee.
     */
    function setMarketplaceFeePercentage(uint8 _percentage) external onlyOwner {
        require(
            _percentage <= 100,
            "setMarketplaceFeePercentage::_percentage must be <= 100"
        );
        marketplaceFeePercentage = _percentage;
    }

    /////////////////////////////////////////////////////////////////////////
    // calculateMarketplaceFee
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Utility function for calculating the marketplace fee for given amount of wei.
     * @param _amount uint256 wei amount.
     * @return uint256 wei fee.
     */
    function calculateMarketplaceFee(uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return _amount.mul(marketplaceFeePercentage).div(100);
    }

    /////////////////////////////////////////////////////////////////////////
    // getERC721ContractPrimarySaleFeePercentage
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Get the primary sale fee percentage for a specific ERC721 contract.
     * @param _contractAddress address ERC721Contract address.
     * @return uint8 wei primary sale fee.
     */
    function getERC721ContractPrimarySaleFeePercentage(address _contractAddress)
        external
        view
        override
        returns (uint8)
    {
        return primarySaleFees[_contractAddress];
    }

    /////////////////////////////////////////////////////////////////////////
    // setERC721ContractPrimarySaleFeePercentage
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Set the primary sale fee percentage for a specific ERC721 contract.
     * Requirements:
     *
     * - `_contractAddress` cannot be the zero address.
     * - `_percentage` must be <= 100.
     * @param _contractAddress address ERC721Contract address.
     * @param _percentage uint8 percentage fee for the ERC721 contract.
     */
    function setERC721ContractPrimarySaleFeePercentage(
        address _contractAddress,
        uint8 _percentage
    ) external onlyOwner {
        require(
            _percentage <= 100,
            "setERC721ContractPrimarySaleFeePercentage::_percentage must be <= 100"
        );
        primarySaleFees[_contractAddress] = _percentage;
    }

    /////////////////////////////////////////////////////////////////////////
    // calculatePrimarySaleFee
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Utility function for calculating the primary sale fee for given amount of wei
     * @param _contractAddress address ERC721Contract address.
     * @param _amount uint256 wei amount.
     * @return uint256 wei fee.
     */
    function calculatePrimarySaleFee(address _contractAddress, uint256 _amount)
        external
        view
        override
        returns (uint256)
    {
        return _amount.mul(primarySaleFees[_contractAddress]).div(100);
    }

    /////////////////////////////////////////////////////////////////////////
    // hasERC721TokenSold
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Check whether the ERC721 token has sold at least once.
     * @param _contractAddress address ERC721Contract address.
     * @param _tokenId uint256 token ID.
     * @return bool of whether the token has sold.
     */
    function hasERC721TokenSold(address _contractAddress, uint256 _tokenId)
        external
        view
        override
        returns (bool)
    {
        return soldTokens[_contractAddress][_tokenId];
    }

    /////////////////////////////////////////////////////////////////////////
    // markERC721TokenAsSold
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Mark a token as sold.
     * Requirements:
     *
     * - `_contractAddress` cannot be the zero address.
     * @param _contractAddress address ERC721Contract address.
     * @param _tokenId uint256 token ID.
     * @param _hasSold bool of whether the token should be marked sold or not.
     */
    function markERC721Token(
        address _contractAddress,
        uint256 _tokenId,
        bool _hasSold
    ) external override {
        require(
            hasRole(TOKEN_MARK_ROLE, msg.sender),
            "markERC721Token::Must have TOKEN_MARK_ROLE role to call method"
        );
        soldTokens[_contractAddress][_tokenId] = _hasSold;
    }

    /////////////////////////////////////////////////////////////////////////
    // markTokensAsSold
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Function to set an array of tokens for a contract as sold, thus not being subject to the primary sale fee, if one exists.
     * @param _originContract address of ERC721 contract.
     * @param _tokenIds uint256[] array of token ids.
     */
    function markTokensAsSold(
        address _originContract,
        uint256[] calldata _tokenIds
    ) external {
        require(
            hasRole(TOKEN_MARK_ROLE, msg.sender),
            "markERC721Token::Must have TOKEN_MARK_ROLE role to call method"
        );
        // limit to batches of 2000
        require(
            _tokenIds.length <= 2000,
            "markTokensAsSold::Attempted to mark more than 2000 tokens as sold"
        );

        // Mark provided tokens as sold.
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            soldTokens[_originContract][_tokenIds[i]] = true;
        }
    }
}
