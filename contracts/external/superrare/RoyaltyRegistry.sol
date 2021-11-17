// SPDX-License-Identifier: MIT
pragma solidity 0.7.3;

import "./interfaces//IERC721CreatorRoyalty.sol";
import "@openzeppelin/contracts2/access/Ownable.sol";
import "@openzeppelin/contracts2/access/AccessControl.sol";
import "@openzeppelin/contracts2/math/SafeMath.sol";

contract RoyaltyRegistry is Ownable, AccessControl, IERC721CreatorRoyalty {
    using SafeMath for uint256;

    bytes32 public constant ROYALTY_FEE_SETTER_ROLE =
        keccak256("ROYALTY_FEE_SETTER_ROLE");

    mapping(address => uint8) private contractRoyaltyPercentage;

    IERC721TokenCreator public iERC721TokenCreator;

    constructor(address _iERC721TokenCreator) {
        require(
            _iERC721TokenCreator != address(0),
            "constructor::_iERC721TokenCreator cannot be the zero address"
        );
        _setupRole(AccessControl.DEFAULT_ADMIN_ROLE, _msgSender());
        iERC721TokenCreator = IERC721TokenCreator(_iERC721TokenCreator);
    }

    function setIERC721TokenCreator(address _contractAddress)
        external
        onlyOwner
    {
        require(
            _contractAddress != address(0),
            "setIERC721TokenCreator::_contractAddress cannot be null"
        );

        iERC721TokenCreator = IERC721TokenCreator(_contractAddress);
    }

    function getERC721TokenRoyaltyPercentage(
        address _contractAddress,
        uint256 //_tokenId
    ) public view override returns (uint8) {
        return contractRoyaltyPercentage[_contractAddress];
    }

    function getPercentageForSetERC721ContractRoyalty(address _contractAddress)
        external
        view
        returns (uint8)
    {
        return contractRoyaltyPercentage[_contractAddress];
    }

    function setPercentageForSetERC721ContractRoyalty(
        address _contractAddress,
        uint8 _percentage
    ) external override {
        require(
            hasRole(ROYALTY_FEE_SETTER_ROLE, _msgSender()),
            "setPercentageForSetERC721ContractRoyalty::Caller must have royalty fee setter role"
        );
        require(
            _percentage <= 100,
            "setPercentageForSetERC721ContractRoyalty::_percentage must be <= 100"
        );
        contractRoyaltyPercentage[_contractAddress] = _percentage;
    }

    function calculateRoyaltyFee(
        address _contractAddress,
        uint256 _tokenId,
        uint256 _amount
    ) external view override returns (uint256) {
        return
            _amount
                .mul(
                    getERC721TokenRoyaltyPercentage(_contractAddress, _tokenId)
                )
                .div(100);
    }

    function tokenCreator(address _contractAddress, uint256 _tokenId)
        external
        view
        override
        returns (address payable)
    {
        return iERC721TokenCreator.tokenCreator(_contractAddress, _tokenId);
    }
}
