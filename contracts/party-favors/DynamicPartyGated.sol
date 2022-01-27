// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ Internal Imports ============
import {IPartyBid} from "../IPartyBid.sol";
import {IPartyBidFactory} from "../IPartyBidFactory.sol";
// ============ External Imports ============
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DynamicPartyGated
 * @author Anna Carroll
 * @notice Only allow contributors to a *dynamically increasing set* of parties
 * to call a function with onlyContributors modifier
 */
contract DynamicPartyGated is Ownable {
    //======== Immutable Storage =========

    // the PartyBid Factory address
    address public immutable partyBidFactory;

    //======== Mutable Storage =========

    // the list of PartyBids to gate contributors
    address[] public parties;

    //======== Modifiers =========

    /**
     * @notice Gate a function to only be callable by
     * contributors to the specified parties
     * @dev reverts if msg.sender did not contribute to any of the parties
     */
    modifier onlyContributors() {
        require(isContributor(msg.sender), "DynamicPartyGated:onlyContributors");
        _;
    }

    //======== Constructor =========

    /**
     * @notice Supply the PartyBids for gating contributors
     * @param _partyBidFactory address of the PartyBid Factory
     * @param _parties array of PartyBid addresses whose contributors to restrict to
     */
    constructor(address _partyBidFactory, address[] memory _parties) {
        require(_parties.length > 0, "DynamicPartyGated::constructor: supply at least one party");
        for (uint256 i = 0; i < _parties.length; i++) {
            _addParty(_partyBidFactory, _parties[i]);
        }
        partyBidFactory = _partyBidFactory;
    }

    //======== Public Functions =========

    /**
     * @notice Determine whether a contributor
     * participated in the specified parties
     * @param _contributor address that might have contributed to parties
     * @return TRUE if they contributed
     */
    function isContributor(address _contributor) public view returns (bool) {
        for (uint256 i = 0; i < parties.length; i++) {
            if (IPartyBid(parties[i]).totalContributed(_contributor) > 0) {
                return true;
            }
        }
        return false;
    }

    //======== External Functions =========

    /**
     * @notice Add a new party to include a new set of contributors
     * @dev only callable by contract owner
     * @param _party address of the PartyBid
     */
    function addParty(address _party) external onlyOwner {
        _addParty(partyBidFactory, _party);
    }

    //======== Internal Functions =========

    /**
     * @notice Add a new party to include a new set of contributors
     * @param _partyBidFactory address of the PartyBid Factory
     * @param _party address of the PartyBid
     */
    function _addParty(address _partyBidFactory, address _party) internal {
        uint256 _deployedAtBlock = IPartyBidFactory(_partyBidFactory).deployedAt(_party);
        require(_deployedAtBlock != 0, "DynamicPartyGated::_addParty: not a party");
        parties.push(_party);
    }
}
