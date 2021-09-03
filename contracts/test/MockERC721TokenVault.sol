//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../external/fractional/ERC721TokenVault.sol";

contract MockTokenVault is TokenVault {
   constructor(address _settings) TokenVault(_settings) {}

   function _sendWETH(address who, uint256 amount) override internal {
        payable(who).transfer(amount);
        // IWETH(weth).deposit{value: amount}();
        // IWETH(weth).transfer(who, IWETH(weth).balanceOf(address(this)));
    }

    /// @dev internal helper function to send ETH and WETH on failure
    function _sendETHOrWETH(address who, uint256 amount) override internal {
        // // contracts get bet WETH because they can be mean
        // if (who.isContract()) {
        //     IWETH(weth).deposit{value: amount}();
        //     IWETH(weth).transfer(who, IWETH(weth).balanceOf(address(this)));
        // } else {
        //     payable(who).transfer(amount);
        // }
    }

}
