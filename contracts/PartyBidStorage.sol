// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {
    IERC721Metadata
} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";

// ============ Internal Imports ============
import {IMarketWrapper} from "./interfaces/IMarketWrapper.sol";
import {ResellerWhitelist} from "./ResellerWhitelist.sol";

contract PartyBidStorage {
    // ============ Enums ============

    // State Transitions:
    // Win Auction
    //   (1) AUCTION_ACTIVE on deploy
    //   (2) AUCTION_WON on finalize()
    //   (3) NFT_TRANSFERRED after supportReseller() passes quorum
    // Lose Auction
    //   (1) AUCTION_ACTIVE on deploy
    //   (2) AUCTION_LOST on finalize()
    enum PartyStatus {
        AUCTION_ACTIVE,
        AUCTION_WON,
        AUCTION_LOST,
        NFT_TRANSFERRED
    }

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        uint256 previousTotalContributedToParty;
    }

    // ============ ERC-20 Public Constants ============

    // solhint-disable-next-line const-name-snakecase
    uint8 public constant decimals = 18;

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyBid pays a 5% fee to PartyDAO
    uint8 internal constant FEE_PERCENT = 5;
    IWETH internal constant WETH =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 internal constant REENTRANCY_NOT_ENTERED = 1;
    uint256 internal constant REENTRANCY_ENTERED = 2;

    // ============ Public Not-Mutated Storage ============

    // address of PartyBid logic contract
    address public logic;
    address public partyDAOMultisig;
    // market wrapper contract exposing interface for
    // market auctioning the NFT
    IMarketWrapper public marketWrapper;
    // whitelist of approved resellers
    ResellerWhitelist public resellerWhitelist;
    // NFT contract
    IERC721Metadata public nftContract;
    uint256 public auctionId;
    uint256 public tokenId;
    // percent (from 1 - 100) of the total token supply
    // required to vote to successfully execute a sale proposal
    uint256 public quorumPercent;

    // ============ Public Mutable Storage ============

    // state of the contract
    PartyStatus public partyStatus;
    // total ETH deposited by all contributors
    uint256 public totalContributedToParty;
    // the highest bid submitted by PartyBid
    uint256 public highestBid;
    // the total spent by PartyBid on the auction;
    // 0 if the NFT is lost; highest bid + 5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // amount of votes for a reseller to pass quorum threshold
    uint256 public supportNeededForQuorum;
    // the ETH balance of the contract from unclaimed contributions
    // decremented each time excess contributions are claimed
    // used to determine the ETH balance of the contract from resale proceeds
    uint256 public excessContributions;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;
    // contributor => voting power (used to support resellers)
    mapping(address => uint256) public votingPower;
    // contributor => reseller => reseller calldata => bool hasSupported
    mapping(address => mapping(address => mapping(bytes => bool)))
        public hasSupportedReseller;
    // reseller => reseller calldata => total support for reseller
    mapping(address => mapping(bytes => uint256)) public resellerSupport;

    // ============ ERC-20 Public Not-Mutated Storage ============

    string public name;
    string public symbol;

    // ============ ERC-20 Public Mutable Storage ============

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    // ============ Internal Mutable Storage ============

    uint256 internal reentrancyStatus;
}
