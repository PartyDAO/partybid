// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

// ============ Internal Imports ============
import {IPartyBid} from "../IPartyBid.sol";

/**
 * @title PartyPeople
 * @author Anna Carroll
 * @notice PartyPeople contract can be inherited
 * by any contract that wants to easily use
 * the onlyPartyPeople modifier in order to dispense
 * party favors to contributors from a defined set of parties
 */
contract PartyPeople {
    //======== Immutable Storage =========

    // the list of PartyBids you wish to gate with
    address[] public parties;

    //======== Modifiers =========

    /**
     * @notice Gate a function to only be callable by
     * contributors to the specified parties
     * @dev reverts if msg.sender did not contribute to any of the parties
     */
    modifier onlyPartyPeople() {
        require(isPartyPerson(msg.sender), "PartyPeople:onlyPartyPeople");
        _;
    }

    //======== Constructor =========

    /**
     * @notice Supply the PartyBids you wish to gate with
     * @param _parties array of PartyBid addresses whose contributors to restrict to
     */
    constructor(address[] memory _parties) {
        require(_parties.length > 0, "PartyPeople::constructor: supply at least one party");
        for (uint256 i = 0; i < _parties.length; i++) {
            address _party = _parties[i];
            // TODO: require is a contract?
            // TODO: require was deployed by partybid factory?
            // TODO: require parties is less than certain length?
            // TODO: require that party is unique?
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
    function isPartyPerson(address _contributor) public returns (bool) {
        for (uint256 i = 0; i < parties.length; i++) {
            if (IPartyBid(parties[i]).totalContributed(_contributor) > 0) {
                return true;
            }
        }
        return false;
    }
}
