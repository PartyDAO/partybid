pragma solidity 0.7.3;

import "@openzeppelin/contracts2/payment/PullPayment.sol";
import "./MaybeSendValue.sol";

/**
 * @dev Contract to make payments. If a direct transfer fails, it will store the payment in escrow until the address decides to pull the payment.
 */
contract SendValueOrEscrow is MaybeSendValue, PullPayment {
    /////////////////////////////////////////////////////////////////////////
    // Events
    /////////////////////////////////////////////////////////////////////////
    event SendValue(address indexed _payee, uint256 amount);

    /////////////////////////////////////////////////////////////////////////
    // sendValueOrEscrow
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Send some value to an address.
     * @param _to address to send some value to.
     * @param _value uint256 amount to send.
     */
    function sendValueOrEscrow(address payable _to, uint256 _value) internal {
        // attempt to make the transfer
        bool successfulTransfer = MaybeSendValue.maybeSendValue(_to, _value);
        // if it fails, transfer it into escrow for them to redeem at their will.
        if (!successfulTransfer) {
            _asyncTransfer(_to, _value);
        }
        emit SendValue(_to, _value);
    }
}