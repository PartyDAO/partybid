// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ Internal Imports ============
import {IPartyBid} from "../IPartyBid.sol";
import {IPartyBidFactory} from "../IPartyBidFactory.sol";

/**
 * @title SinglePartyGated
 * @author Anna Carroll
 * @notice Only allow contributors to a *single* party
 * to call a function with onlyContributors modifier
 */
contract SinglePartyGated {
    //======== Immutable Storage =========

    // the PartyBid to gate contributors
    address public immutable party;

    //======== Modifiers =========

    /**
     * @notice Gate a function to only be callable by
     * contributors to the specified party
     * @dev reverts if msg.sender did not contribute to the party
     */
    modifier onlyContributors() {
        require(isContributor(msg.sender), "SinglePartyGated:onlyContributors");
        _;
    }

    //======== Constructor =========

    /**
     * @notice Supply the PartyBids for gating contributors
     * @param _partyBidFactory address of the PartyBid Factory
     * @param _party address of the PartyBid whose contributors to restrict to
     */
    constructor(address _partyBidFactory, address _party) {
        uint256 _deployedAtBlock = IPartyBidFactory(_partyBidFactory).deployedAt(_party);
        require(_deployedAtBlock != 0, "SinglePartyGated::constructor: not a party");
        party = _party;
    }

    //======== Public Functions =========

    /**
     * @notice Determine whether a contributor
     * participated in the specified parties
     * @param _contributor address that might have contributed to parties
     * @return TRUE if they contributed
     */
    function isContributor(address _contributor) public view returns (bool) {
        return IPartyBid(party).totalContributed(_contributor) > 0;
    }
}
