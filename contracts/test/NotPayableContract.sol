// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

contract NonPayableContract {
    function contribute(address partyBid, uint256 amount) public {
        (bool success, bytes memory returnData) =
            partyBid.call{value: amount}(
                abi.encodeWithSignature(
                    "contribute()"
                )
            );
        require(success, string(returnData));
    }
}