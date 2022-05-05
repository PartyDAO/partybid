// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IMarketWrapper} from "./IMarketWrapper.sol";
import {TokenVault} from "../external/fractional/ERC721TokenVault.sol";
import {ERC721VaultFactory} from "../external/fractional/ERC721VaultFactory.sol";
import {Settings} from "../external/fractional/Settings.sol";

contract FractionalMarketWrapper is IMarketWrapper {
    ERC721VaultFactory public vaultFactory;
    Settings public settings;

    constructor(
        address _vaultFactory
    ) {
        vaultFactory = ERC721VaultFactory(_vaultFactory);
        settings = Settings(vaultFactory.settings());
    }

    function auctionIdMatchesToken(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId
    ) external view returns (bool) 
    {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        if (auction.token() != nftContract || auction.id() != tokenId) {
            return false;
        }
        TokenVault.State auctionState = auction.auctionState();
        if (auctionState == TokenVault.State.inactive) {
            // we'd be `start()`ing it
            // see ERC721TokenVault, line 324
            return auction.votingTokens() * 1000 >=
                settings.minVotePercentage() * auction.totalSupply();
        } else if (auctionState == TokenVault.State.live) {
            // we'd be `bid()`ing on it
            return (block.timestamp < auction.auctionEnd());
        } else {
            // auction is State.ended or State.redeemed,
            // which means it is not an active auction
            // and can't be started
            return false;
        }

        return true;
        // correct auction && bid live (&& currency eth?)
    }

    function getCurrentHighestBidder(uint256 auctionId)
        external
        view
        returns (address) {
            TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
            return auction.winning();
        }

    function getMinimumBid(uint256 auctionId) external view returns (uint256) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        
        // see ERC721TokenVault, line 338:339
        uint256 increase = settings.minBidIncrease() + 1000;
        return auction.livePrice() * increase / 1000; // do we need to add 999 wei in case of integer errors?
    }

    function bid(uint256 auctionId, uint256 bidAmount) external {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        TokenVault.State auctionState = auction.auctionState();

        if (auctionState == TokenVault.State.inactive) {
            auction.start{value: bidAmount}();
        } else if (auctionState == TokenVault.State.live) {
            auction.bid{value: bidAmount}();
        }

    }

    function isFinalized(uint256 auctionId) external view returns (bool) {
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        return auction.auctionState() == TokenVault.State.ended;
    }

    function finalize(uint256 auctionId) external {
        // call finalize to fractional
        TokenVault auction = TokenVault(vaultFactory.vaults(auctionId));
        auction.end();

    }
}