//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ITokenVault {
    /// @notice allow curator to update the curator address
    /// @param _curator the new curator
    function updateCurator(address _curator) external;

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) external view returns (uint256);
}