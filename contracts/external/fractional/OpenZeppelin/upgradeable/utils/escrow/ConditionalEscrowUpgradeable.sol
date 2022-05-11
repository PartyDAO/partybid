// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./EscrowUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @title ConditionalEscrow
 * @dev Base abstract escrow to only allow withdrawal if a condition is met.
 * @dev Intended usage: See {Escrow}. Same usage guidelines apply here.
 */
abstract contract ConditionalEscrowUpgradeable is Initializable, EscrowUpgradeable {
    function __ConditionalEscrow_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __Escrow_init_unchained();
        __ConditionalEscrow_init_unchained();
    }

    function __ConditionalEscrow_init_unchained() internal initializer {
    }
    /**
     * @dev Returns whether an address is allowed to withdraw their funds. To be
     * implemented by derived contracts.
     * @param payee The destination address of the funds.
     */
    function withdrawalAllowed(address payee) public view virtual returns (bool);

    function withdraw(address payable payee) public virtual override {
        require(withdrawalAllowed(payee), "ConditionalEscrow: payee is not allowed to withdraw");
        super.withdraw(payee);
    }
    uint256[50] private __gap;
}
