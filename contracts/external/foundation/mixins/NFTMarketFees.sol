// SPDX-License-Identifier: MIT OR Apache-2.0
// Reproduced from https://etherscan.io/address/0xa7d94560dbd814af316dd96fde78b9136a977d1c#code under the terms of Apache-2.0

pragma solidity ^0.7.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "./FoundationTreasuryNode.sol";
import "./Constants.sol";
import "./NFTMarketCore.sol";
import "./NFTMarketCreators.sol";
import "./SendValueWithFallbackWithdraw.sol";

/**
 * @notice A mixin to distribute funds when an NFT is sold.
 */
abstract contract NFTMarketFees is
    Constants,
    Initializable,
    FoundationTreasuryNode,
    NFTMarketCore,
    NFTMarketCreators,
    SendValueWithFallbackWithdraw
{
    using SafeMathUpgradeable for uint256;

    event MarketFeesUpdated(
        uint256 primaryFoundationFeeBasisPoints,
        uint256 secondaryFoundationFeeBasisPoints,
        uint256 secondaryCreatorFeeBasisPoints
    );

    uint256 private _primaryFoundationFeeBasisPoints;
    uint256 private _secondaryFoundationFeeBasisPoints;
    uint256 private _secondaryCreatorFeeBasisPoints;

    mapping(address => mapping(uint256 => bool))
        private nftContractToTokenIdToFirstSaleCompleted;

    /**
     * @notice Returns true if the given NFT has not been sold in this market previously and is being sold by the creator.
     */
    function getIsPrimary(address nftContract, uint256 tokenId)
        public
        view
        returns (bool)
    {
        return
            _getIsPrimary(
                nftContract,
                tokenId,
                _getSellerFor(nftContract, tokenId)
            );
    }

    /**
     * @dev A helper that determines if this is a primary sale given the current seller.
     * This is a minor optimization to use the seller if already known instead of making a redundant lookup call.
     */
    function _getIsPrimary(
        address nftContract,
        uint256 tokenId,
        address seller
    ) private view returns (bool) {
        // By checking if the first sale has been completed first we can short circuit getCreator which is an external call.
        return
            !nftContractToTokenIdToFirstSaleCompleted[nftContract][tokenId] &&
            getCreator(nftContract, tokenId) == seller;
    }

    /**
     * @notice Returns the current fee configuration in basis points.
     */
    function getFeeConfig()
        public
        view
        returns (
            uint256 primaryFoundationFeeBasisPoints,
            uint256 secondaryFoundationFeeBasisPoints,
            uint256 secondaryCreatorFeeBasisPoints
        )
    {
        return (
            _primaryFoundationFeeBasisPoints,
            _secondaryFoundationFeeBasisPoints,
            _secondaryCreatorFeeBasisPoints
        );
    }

    /**
     * @notice Returns how funds will be distributed for a sale at the given price point.
     * @dev This could be used to present exact fee distributing on listing or before a bid is placed.
     */
    function getFees(
        address nftContract,
        uint256 tokenId,
        uint256 price
    )
        public
        view
        returns (
            uint256 foundationFee,
            uint256 creatorSecondaryFee,
            uint256 ownerRev
        )
    {
        return
            _getFees(
                nftContract,
                tokenId,
                _getSellerFor(nftContract, tokenId),
                price
            );
    }

    /**
     * @dev Calculates how funds should be distributed for the given sale details.
     * If this is a primary sale, the creator revenue will appear as `ownerRev`.
     */
    function _getFees(
        address nftContract,
        uint256 tokenId,
        address seller,
        uint256 price
    )
        public
        view
        returns (
            uint256 foundationFee,
            uint256 creatorSecondaryFee,
            uint256 ownerRev
        )
    {
        uint256 foundationFeeBasisPoints;
        if (_getIsPrimary(nftContract, tokenId, seller)) {
            foundationFeeBasisPoints = _primaryFoundationFeeBasisPoints;
            // On a primary sale, the creator is paid the remainder via `ownerRev`.
        } else {
            foundationFeeBasisPoints = _secondaryFoundationFeeBasisPoints;
            // SafeMath is not required when dividing by a constant value > 0.
            creatorSecondaryFee =
                price.mul(_secondaryCreatorFeeBasisPoints) /
                BASIS_POINTS;
        }
        // SafeMath is not required when dividing by a constant value > 0.
        foundationFee = price.mul(foundationFeeBasisPoints) / BASIS_POINTS;
        ownerRev = price.sub(foundationFee).sub(creatorSecondaryFee);
    }

    /**
     * @dev Distributes funds to foundation, creator, and NFT owner after a sale.
     */
    function _distributeFunds(
        address nftContract,
        uint256 tokenId,
        address payable seller,
        uint256 price
    )
        internal
        returns (
            uint256 foundationFee,
            uint256 creatorFee,
            uint256 ownerRev
        )
    {
        (foundationFee, creatorFee, ownerRev) = _getFees(
            nftContract,
            tokenId,
            seller,
            price
        );

        // Anytime fees are distributed that indicates the first sale is complete,
        // which will not change state during a secondary sale.
        // This must come after the `_getFees` call above as this state is considered in the function.
        nftContractToTokenIdToFirstSaleCompleted[nftContract][tokenId] = true;

        _sendValueWithFallbackWithdraw(getFoundationTreasury(), foundationFee);
        if (creatorFee > 0) {
            address payable creator = getCreator(nftContract, tokenId);
            if (creator == address(0)) {
                // If the creator is unknown, send all revenue to the current seller instead.
                ownerRev = ownerRev.add(creatorFee);
                creatorFee = 0;
            } else {
                _sendValueWithFallbackWithdraw(creator, creatorFee);
            }
        }
        _sendValueWithFallbackWithdraw(seller, ownerRev);
    }

    /**
     * @notice Allows Foundation to change the market fees.
     */
    function _updateMarketFees(
        uint256 primaryFoundationFeeBasisPoints,
        uint256 secondaryFoundationFeeBasisPoints,
        uint256 secondaryCreatorFeeBasisPoints
    ) internal {
        require(
            primaryFoundationFeeBasisPoints < BASIS_POINTS,
            "NFTMarketFees: Fees >= 100%"
        );
        require(
            secondaryFoundationFeeBasisPoints.add(
                secondaryCreatorFeeBasisPoints
            ) < BASIS_POINTS,
            "NFTMarketFees: Fees >= 100%"
        );
        _primaryFoundationFeeBasisPoints = primaryFoundationFeeBasisPoints;
        _secondaryFoundationFeeBasisPoints = secondaryFoundationFeeBasisPoints;
        _secondaryCreatorFeeBasisPoints = secondaryCreatorFeeBasisPoints;

        emit MarketFeesUpdated(
            primaryFoundationFeeBasisPoints,
            secondaryFoundationFeeBasisPoints,
            secondaryCreatorFeeBasisPoints
        );
    }

    uint256[1000] private ______gap;
}
