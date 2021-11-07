// SPDX-License-Identifier: GPL-3.0

/// @title The Koans mock offer contract

pragma solidity ^0.8.6;

import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IKoansToken } from "./interfaces/IKoansToken.sol";
import { IKoansAuctionHouse } from "./interfaces/IKoansAuctionHouse.sol";
import { ISashoToken } from "./interfaces/ISashoToken.sol";
import { IOffer } from "./interfaces/IOffer.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockOffer is IOffer {

    IKoansAuctionHouse public auctionHouse;

    constructor (IKoansAuctionHouse _auctionHouse) {
        auctionHouse = _auctionHouse;
    }

    /**
     * @notice Generate a mock Noun seed.
     */
    function addOffer(string memory uriPath, address payoutAddress) external {
        auctionHouse.addOffer(uriPath, payoutAddress);
    }

    function pause() external override {}

    function unpause() external override {}

    function settleOfferPeriod() external override {}

    function settleCurrentAndCreateNewOfferPeriod() external override {}

    function setKoanVotingWeight(uint koanVotingWeight_) external override {}

    function setMinCollateral(uint minCollateral_) external override {}

    function setOfferFee(uint offerFee_) external override {}

    function setOfferDurationBlocks(uint offerDurationBlocks_) external override {}

    function setVotingPeriodDurationBlocks(uint votingPeriodDurationBlocks_) external override{}
}
