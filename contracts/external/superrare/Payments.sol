pragma solidity 0.7.3;

import "@openzeppelin/contracts2/math/SafeMath.sol";
import "./SendValueOrEscrow.sol";

/**
 * @title Payments contract for SuperRare Marketplaces.
 */
contract Payments is SendValueOrEscrow {
    using SafeMath for uint256;
    using SafeMath for uint8;

    /////////////////////////////////////////////////////////////////////////
    // refund
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Internal function to refund an address. Typically for canceled bids or offers.
     * Requirements:
     *
     *  - _payee cannot be the zero address
     *
     * @param _marketplacePercentage uint8 percentage of the fee for the marketplace.
     * @param _amount uint256 value to be split.
     * @param _payee address seller of the token.
     */
    function refund(
        uint8 _marketplacePercentage,
        address payable _payee,
        uint256 _amount
    ) internal {
        require(
            _payee != address(0),
            "refund::no payees can be the zero address"
        );

        if (_amount > 0) {
            SendValueOrEscrow.sendValueOrEscrow(
                _payee,
                _amount.add(
                    calcPercentagePayment(_amount, _marketplacePercentage)
                )
            );
        }
    }

    /////////////////////////////////////////////////////////////////////////
    // payout
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Internal function to pay the seller, creator, and maintainer.
     * Requirements:
     *
     *  - _marketplacePercentage + _royaltyPercentage + _primarySalePercentage <= 100
     *  - no payees can be the zero address
     *
     * @param _amount uint256 value to be split.
     * @param _isPrimarySale bool of whether this is a primary sale.
     * @param _marketplacePercentage uint8 percentage of the fee for the marketplace.
     * @param _royaltyPercentage uint8 percentage of the fee for the royalty.
     * @param _primarySalePercentage uint8 percentage primary sale fee for the marketplace.
     * @param _payee address seller of the token.
     * @param _marketplacePayee address seller of the token.
     * @param _royaltyPayee address seller of the token.
     * @param _primarySalePayee address seller of the token.
     */
    function payout(
        uint256 _amount,
        bool _isPrimarySale,
        uint8 _marketplacePercentage,
        uint8 _royaltyPercentage,
        uint8 _primarySalePercentage,
        address payable _payee,
        address payable _marketplacePayee,
        address payable _royaltyPayee,
        address payable _primarySalePayee
    ) internal {
        require(
            _marketplacePercentage <= 100,
            "payout::marketplace percentage cannot be above 100"
        );
        require(
            _royaltyPercentage.add(_primarySalePercentage) <= 100,
            "payout::percentages cannot go beyond 100"
        );
        require(
            _payee != address(0) &&
                _primarySalePayee != address(0) &&
                _marketplacePayee != address(0) &&
                _royaltyPayee != address(0),
            "payout::no payees can be the zero address"
        );

        // Note:: Solidity is kind of terrible in that there is a limit to local
        //        variables that can be put into the stack. The real pain is that
        //        one can put structs, arrays, or mappings into memory but not basic
        //        data types. Hence our payments array that stores these values.
        uint256[4] memory payments;

        // uint256 marketplacePayment
        payments[0] = calcPercentagePayment(_amount, _marketplacePercentage);

        // uint256 royaltyPayment
        payments[1] = calcRoyaltyPayment(
            _isPrimarySale,
            _amount,
            _royaltyPercentage
        );

        // uint256 primarySalePayment
        payments[2] = calcPrimarySalePayment(
            _isPrimarySale,
            _amount,
            _primarySalePercentage
        );

        // uint256 payeePayment
        payments[3] = _amount.sub(payments[1]).sub(payments[2]);

        // marketplacePayment
        if (payments[0] > 0) {
            SendValueOrEscrow.sendValueOrEscrow(_marketplacePayee, payments[0]);
        }

        // royaltyPayment
        if (payments[1] > 0) {
            SendValueOrEscrow.sendValueOrEscrow(_royaltyPayee, payments[1]);
        }
        // primarySalePayment
        if (payments[2] > 0) {
            SendValueOrEscrow.sendValueOrEscrow(_primarySalePayee, payments[2]);
        }
        // payeePayment
        if (payments[3] > 0) {
            SendValueOrEscrow.sendValueOrEscrow(_payee, payments[3]);
        }
    }

    /////////////////////////////////////////////////////////////////////////
    // calcRoyaltyPayment
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Private function to calculate Royalty amount.
     *      If primary sale: 0
     *      If no royalty percentage: 0
     *      otherwise: royalty in wei
     * @param _isPrimarySale bool of whether this is a primary sale
     * @param _amount uint256 value to be split
     * @param _percentage uint8 royalty percentage
     * @return uint256 wei value owed for royalty
     */
    function calcRoyaltyPayment(
        bool _isPrimarySale,
        uint256 _amount,
        uint8 _percentage
    ) private pure returns (uint256) {
        if (_isPrimarySale) {
            return 0;
        }
        return calcPercentagePayment(_amount, _percentage);
    }

    /////////////////////////////////////////////////////////////////////////
    // calcPrimarySalePayment
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Private function to calculate PrimarySale amount.
     *      If not primary sale: 0
     *      otherwise: primary sale in wei
     * @param _isPrimarySale bool of whether this is a primary sale
     * @param _amount uint256 value to be split
     * @param _percentage uint8 royalty percentage
     * @return uint256 wei value owed for primary sale
     */
    function calcPrimarySalePayment(
        bool _isPrimarySale,
        uint256 _amount,
        uint8 _percentage
    ) private pure returns (uint256) {
        if (_isPrimarySale) {
            return calcPercentagePayment(_amount, _percentage);
        }
        return 0;
    }

    /////////////////////////////////////////////////////////////////////////
    // calcPercentagePayment
    /////////////////////////////////////////////////////////////////////////
    /**
     * @dev Internal function to calculate percentage value.
     * @param _amount uint256 wei value
     * @param _percentage uint8  percentage
     * @return uint256 wei value based on percentage.
     */
    function calcPercentagePayment(uint256 _amount, uint8 _percentage)
        internal
        pure
        returns (uint256)
    {
        return _amount.mul(_percentage).div(100);
    }
}