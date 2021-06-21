pragma solidity 0.8.5;

interface ITokenVault {
    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice allow curator to update the curator address
    /// @param _curator the new curator
    function updateCurator(address _curator) external;
}