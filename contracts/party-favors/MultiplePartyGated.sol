// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ Internal Imports ============
import {IPartyBid} from "../IPartyBid.sol";
import {IPartyBidFactory} from "../IPartyBidFactory.sol";

/**
 * @title MultiplePartyGated
 * @author Anna Carroll
 * @notice Only allow contributors to a *defined set* of parties
 * to call a function with onlyContributors modifier
 */
contract MultiplePartyGated {
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
        require(isContributor(msg.sender), "MultiplePartyGated:onlyContributors");
        _;
    }

    //======== Constructor =========

    /**
     * @notice Supply the PartyBids for gating contributors
     * @param _partyBidFactory address of the PartyBid Factory
     * @param _parties array of PartyBid addresses whose contributors to restrict to
     */
    constructor(address _partyBidFactory, address[] memory _parties) {
        require(_parties.length > 0, "MultiplePartyGated::constructor: supply at least one party");
        for (uint256 i = 0; i < _parties.length; i++) {
            address _party = _parties[i];
            uint256 _deployedAtBlock = IPartyBidFactory(_partyBidFactory).deployedAt(_party);
            require(_deployedAtBlock != 0, "MultiplePartyGated::constructor: not a party");
            parties.push(_party);
        }
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
}
