// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

// ============ External Imports ============
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PartyBid
 * @author Anna Carroll
 * @notice Whitelist of approved Resellers for PartyBid instances
 * Owned and updated by PartyDAO multisig
 */
contract ResellerWhitelist is Ownable {
    // ============ Public Mutable Storage ============

    // address reseller -> bool isWhitelisted for all PartyBid instances
    mapping(address => bool) public whitelistForAll;
    // address PartyBid -> mapping address reseller -> bool isWhitelisted for specific PartyBid instance
    mapping(address => mapping(address => bool)) public whitelistPerPartyBid;

    // ======== Public =========

    /**
     * @notice Return true if reseller is whitelisted for
     * the given PartyBid
     * @param _partyBid address of the PartyBid contract
     * @param _reseller address of the potential reseller
     * @return TRUE if the reseller is approved for the given PartyBid, FALSE if not
     */
    function isWhitelisted(address _partyBid, address _reseller)
        public
        view
        returns (bool)
    {
        return
            whitelistForAll[_reseller] ||
            whitelistPerPartyBid[_partyBid][_reseller];
    }

    // ======== External, Owner-Only =========

    /**
     * @notice Whitelist the reseller for all PartyBid instances
     * @param _reseller address of the approved reseller
     * @param _isWhitelisted TRUE if the reseller is approved, FALSE if not
     */
    function updateWhitelistForAll(address _reseller, bool _isWhitelisted)
        external
        onlyOwner
    {
        whitelistForAll[_reseller] = _isWhitelisted;
    }

    /**
     * @notice Whitelist the reseller for a specific PartyBid instance
     * @param _partyBid address of the PartyBid contract
     * @param _reseller address of the approved reseller
     * @param _isWhitelisted TRUE if the reseller is approved, FALSE if not
     */
    function updateWhitelistForOne(
        address _partyBid,
        address _reseller,
        bool _isWhitelisted
    ) external onlyOwner {
        whitelistPerPartyBid[_partyBid][_reseller] = _isWhitelisted;
    }
}
