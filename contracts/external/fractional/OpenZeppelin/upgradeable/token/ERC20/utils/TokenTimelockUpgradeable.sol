// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SafeERC20Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 *
 * Useful for simple vesting schedules like "advisors get all of their tokens
 * after 1 year".
 */
contract TokenTimelockUpgradeable is Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // ERC20 basic token contract being held
    IERC20Upgradeable private _token;

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // timestamp when token release is enabled
    uint256 private _releaseTime;

    function __TokenTimelock_init(
        IERC20Upgradeable token_,
        address beneficiary_,
        uint256 releaseTime_
    ) internal initializer {
        __TokenTimelock_init_unchained(token_, beneficiary_, releaseTime_);
    }

    function __TokenTimelock_init_unchained(
        IERC20Upgradeable token_,
        address beneficiary_,
        uint256 releaseTime_
    ) internal initializer {
        require(releaseTime_ > block.timestamp, "TokenTimelock: release time is before current time");
        _token = token_;
        _beneficiary = beneficiary_;
        _releaseTime = releaseTime_;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20Upgradeable) {
        return _token;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

    /**
     * @return the time when the tokens are released.
     */
    function releaseTime() public view virtual returns (uint256) {
        return _releaseTime;
    }

    /**
     * @notice Transfers tokens held by timelock to beneficiary.
     */
    function release() public virtual {
        require(block.timestamp >= releaseTime(), "TokenTimelock: current time is before release time");

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TokenTimelock: no tokens to release");

        token().safeTransfer(beneficiary(), amount);
    }
    uint256[50] private __gap;
}
