// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

interface IPartyBid {
    // ============ Enums ============

    // State Transitions:
    //   (1) AUCTION_ACTIVE on deploy
    //   (2) AUCTION_WON or AUCTION_LOST on finalize()
    enum PartyStatus {AUCTION_ACTIVE, AUCTION_WON, AUCTION_LOST}

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        uint256 previousTotalContributedToParty;
    }

    // ============ Public Storage Variables ============

    // market wrapper contract exposing interface for
    // market auctioning the NFT
    function marketWrapper() external returns(address);

    // NFT contract
    function nftContract() external returns(address);

    // Fractionalized NFT vault responsible for post-auction value capture
    function tokenVault() external returns(address);

    // ID of auction within market contract
    function auctionId() external returns(uint256);

    // ID of token within NFT contract
    function tokenId() external returns(uint256);

    // ERC-20 symbol for fractional tokens
    function symbol() external returns(string memory);

    // ERC-20 name for fractional tokens
    function name() external returns(string memory);

    // state of the contract
    function partyStatus() external returns(PartyStatus);

    // total ETH deposited by all contributors
    function totalContributedToParty() external returns(uint256);

    // the total spent by PartyBid on the auction;
    // 0 if the NFT is lost; highest bid + 5% PartyDAO fee if NFT is won
    function totalSpent() external returns(uint256);

    // the highest bid submitted by PartyBid
    function highestBid() external returns(uint256);

    // contributor => array of Contributions
    function contributions(address _contributor) external returns(Contribution[] memory);

    // contributor => total amount contributed
    function totalContributed(address _contributor) external returns(uint256);

    // contributor => true if contribution has been claimed
    function claimed(address _contributor) external returns(bool);


    // ======== Initializer =========

    function initialize(
        address _marketWrapper,
        address _nftContract,
        uint256 _tokenId,
        uint256 _auctionId,
        string memory _name,
        string memory _symbol
    ) external;

    // ======== External: Contribute =========

    /**
     * @notice Contribute to the PartyBid's treasury
     * while the auction is still open
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function contribute() external payable;

    // ======== External: Bid =========

    /**
     * @notice Submit a bid to the Market
     * @dev Reverts if insufficient funds to place the bid and pay PartyDAO fees,
     * or if any external auction checks fail (including if PartyBid is current high bidder)
     * Emits a Bid event upon success.
     * Callable by any contributor
     */
    function bid() external;

    // ======== External: Finalize =========

    /**
     * @notice Finalize the state of the auction
     * @dev Emits a Finalized event upon success; callable by anyone
     */
    function finalize() external;

    // ======== External: Claim =========

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a single contributor after the auction has ended
     * @dev Emits a Claimed event upon success
     * callable by anyone (doesn't have to be the contributor)
     * @param _contributor the address of the contributor
     */
    function claim(address _contributor) external;

    // ======== Public: Utility Calculations =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 _value) external returns (uint256 _tokens);
}
