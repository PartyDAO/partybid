// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

abstract contract NonReentrant {
    // ============ Internal Constants ============

    uint256 internal constant REENTRANCY_NOT_ENTERED = 1;
    uint256 internal constant REENTRANCY_ENTERED = 2;

    // ============ Internal Mutable Storage ============

    uint256 internal reentrancyStatus;

    // ============ Modifiers ============

    /**
     * @notice Prevent re-entrancy attacks
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(reentrancyStatus != REENTRANCY_ENTERED, "no reentrance");
        // Any calls to nonReentrant after this point will fail
        reentrancyStatus = REENTRANCY_ENTERED;
        _;
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        reentrancyStatus = REENTRANCY_NOT_ENTERED;
    }
}
