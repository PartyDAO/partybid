/*
__/\\\\\\\\\\\\\_____________________________________________________________/\\\\\\\\\\\\________/\\\\\\\\\__________/\\\\\______
 _\/\\\/////////\\\__________________________________________________________\/\\\////////\\\____/\\\\\\\\\\\\\______/\\\///\\\____
  _\/\\\_______\/\\\__________________________________/\\\_________/\\\__/\\\_\/\\\______\//\\\__/\\\/////////\\\___/\\\/__\///\\\__
   _\/\\\\\\\\\\\\\/___/\\\\\\\\\_____/\\/\\\\\\\___/\\\\\\\\\\\___\//\\\/\\\__\/\\\_______\/\\\_\/\\\_______\/\\\__/\\\______\//\\\_
    _\/\\\/////////____\////////\\\___\/\\\/////\\\_\////\\\////_____\//\\\\\___\/\\\_______\/\\\_\/\\\\\\\\\\\\\\\_\/\\\_______\/\\\_
     _\/\\\_______________/\\\\\\\\\\__\/\\\___\///_____\/\\\__________\//\\\____\/\\\_______\/\\\_\/\\\/////////\\\_\//\\\______/\\\__
      _\/\\\______________/\\\/////\\\__\/\\\____________\/\\\_/\\___/\\_/\\\_____\/\\\_______/\\\__\/\\\_______\/\\\__\///\\\__/\\\____
       _\/\\\_____________\//\\\\\\\\/\\_\/\\\____________\//\\\\\___\//\\\\/______\/\\\\\\\\\\\\/___\/\\\_______\/\\\____\///\\\\\/_____
        _\///_______________\////////\//__\///______________\/////_____\////________\////////////_____\///________\///_______\/////_______

Anna Carroll for PartyDAO
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

// ============ External Imports: Inherited Contracts ============
// NOTE: we inherit from OpenZeppelin upgradeable contracts
// because of the proxy structure used for cheaper deploys
// (the proxies are NOT actually upgradeable)
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ERC721HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
// ============ External Imports: External Contracts & Contract Interfaces ============
import {IERC721VaultFactory} from "./external/interfaces/IERC721VaultFactory.sol";
import {ITokenVault} from "./external/interfaces/ITokenVault.sol";
import {IWETH} from "./external/interfaces/IWETH.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// ============ Internal Imports ============
import {Structs} from "./Structs.sol";

contract Party is ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
    // ============ Enums ============

    // State Transitions:
    //   (0) ACTIVE on deploy
    //   (1) WON if the Party has won the token
    //   (2) LOST if the Party is over & did not win the token
    enum PartyStatus {
        ACTIVE,
        WON,
        LOST
    }

    // ============ Structs ============

    struct Contribution {
        uint256 amount;
        uint256 previousTotalContributedToParty;
    }

    // ============ Internal Constants ============

    // tokens are minted at a rate of 1 ETH : 1000 tokens
    uint16 internal constant TOKEN_SCALE = 1000;
    // PartyDAO receives an ETH fee equal to 2.5% of the amount spent
    uint16 internal constant ETH_FEE_BASIS_POINTS = 250;
    // PartyDAO receives a token fee equal to 2.5% of the total token supply
    uint16 internal constant TOKEN_FEE_BASIS_POINTS = 250;
    // token is relisted on Fractional with an
    // initial reserve price equal to 2x the price of the token
    uint8 internal constant RESALE_MULTIPLIER = 2;

    // ============ Immutables ============

    address public immutable partyFactory;
    address public immutable partyDAOMultisig;
    IERC721VaultFactory public immutable tokenVaultFactory;
    IWETH public immutable weth;

    // ============ Public Not-Mutated Storage ============

    // NFT contract
    IERC721Metadata public nftContract;
    // ID of token within NFT contract
    uint256 public tokenId;
    // Fractionalized NFT vault responsible for post-purchase experience
    ITokenVault public tokenVault;
    // the address that will receive a portion of the tokens
    // if the Party successfully buys the token
    address public splitRecipient;
    // percent of the total token supply
    // taken by the splitRecipient
    uint256 public splitBasisPoints;
    // address of token that users need to hold to contribute
    // address(0) if party is not token gated
    IERC20 public gatedToken;
    // amount of token that users need to hold to contribute
    // 0 if party is not token gated
    uint256 public gatedTokenAmount;
    // ERC-20 name and symbol for fractional tokens
    string public name;
    string public symbol;

    // ============ Public Mutable Storage ============

    // state of the contract
    PartyStatus public partyStatus;
    // total ETH deposited by all contributors
    uint256 public totalContributedToParty;
    // the total spent buying the token;
    // 0 if the NFT is not won; price of token + 2.5% PartyDAO fee if NFT is won
    uint256 public totalSpent;
    // contributor => array of Contributions
    mapping(address => Contribution[]) public contributions;
    // contributor => total amount contributed
    mapping(address => uint256) public totalContributed;
    // contributor => true if contribution has been claimed
    mapping(address => bool) public claimed;

    // ============ Events ============

    event Contributed(
        address indexed contributor,
        uint256 amount,
        uint256 previousTotalContributedToParty,
        uint256 totalFromContributor
    );

    event Claimed(
        address indexed contributor,
        uint256 totalContributed,
        uint256 excessContribution,
        uint256 tokenAmount
    );

    // ======== Modifiers =========

    modifier onlyPartyDAO() {
        require(
            msg.sender == partyDAOMultisig,
            "Party:: only PartyDAO multisig"
        );
        _;
    }

    // ======== Constructor =========

    constructor(
        address _partyDAOMultisig,
        address _tokenVaultFactory,
        address _weth
    ) {
        partyFactory = msg.sender;
        partyDAOMultisig = _partyDAOMultisig;
        tokenVaultFactory = IERC721VaultFactory(_tokenVaultFactory);
        weth = IWETH(_weth);
    }

    // ======== Internal: Initialize =========

    function __Party_init(
        address _nftContract,
        Structs.AddressAndAmount calldata _split,
        Structs.AddressAndAmount calldata _tokenGate,
        string memory _name,
        string memory _symbol
    ) internal {
        require(
            msg.sender == partyFactory,
            "Party::__Party_init: only factory can init"
        );
        // if split is non-zero,
        if (_split.addr != address(0) && _split.amount != 0) {
            // validate that party split won't retain the total token supply
            uint256 _remainingBasisPoints = 10000 - TOKEN_FEE_BASIS_POINTS;
            require(
                _split.amount < _remainingBasisPoints,
                "Party::__Party_init: basis points can't take 100%"
            );
            splitBasisPoints = _split.amount;
            splitRecipient = _split.addr;
        }
        // if token gating is non-zero
        if (_tokenGate.addr != address(0) && _tokenGate.amount != 0) {
            // call totalSupply to verify that address is ERC-20 token contract
            IERC20(_tokenGate.addr).totalSupply();
            gatedToken = IERC20(_tokenGate.addr);
            gatedTokenAmount = _tokenGate.amount;
        }
        // initialize ReentrancyGuard and ERC721Holder
        __ReentrancyGuard_init();
        __ERC721Holder_init();
        // set storage variables
        nftContract = IERC721Metadata(_nftContract);
        name = _name;
        symbol = _symbol;
    }

    // ======== Internal: Contribute =========

    /**
     * @notice Contribute to the Party's treasury
     * while the Party is still active
     * @dev Emits a Contributed event upon success; callable by anyone
     */
    function _contribute() internal {
        require(
            partyStatus == PartyStatus.ACTIVE,
            "Party::contribute: party not active"
        );
        address _contributor = msg.sender;
        uint256 _amount = msg.value;
        // if token gated, require that contributor has balance of gated tokens
        if (address(gatedToken) != address(0)) {
            require(
                gatedToken.balanceOf(_contributor) >= gatedTokenAmount,
                "Party::contribute: must hold tokens to contribute"
            );
        }
        require(_amount > 0, "Party::contribute: must contribute more than 0");
        // get the current contract balance
        uint256 _previousTotalContributedToParty = totalContributedToParty;
        // add contribution to contributor's array of contributions
        Contribution memory _contribution = Contribution({
            amount: _amount,
            previousTotalContributedToParty: _previousTotalContributedToParty
        });
        contributions[_contributor].push(_contribution);
        // add to contributor's total contribution
        totalContributed[_contributor] =
            totalContributed[_contributor] +
            _amount;
        // add to party's total contribution & emit event
        totalContributedToParty = _previousTotalContributedToParty + _amount;
        emit Contributed(
            _contributor,
            _amount,
            _previousTotalContributedToParty,
            totalContributed[_contributor]
        );
    }

    // ======== External: Claim =========

    /**
     * @notice Claim the tokens and excess ETH owed
     * to a single contributor after the party has ended
     * @dev Emits a Claimed event upon success
     * callable by anyone (doesn't have to be the contributor)
     * @param _contributor the address of the contributor
     */
    function claim(address _contributor) external nonReentrant {
        // ensure party has finalized
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::claim: party not finalized"
        );
        // ensure contributor submitted some ETH
        require(
            totalContributed[_contributor] != 0,
            "Party::claim: not a contributor"
        );
        // ensure the contributor hasn't already claimed
        require(
            !claimed[_contributor],
            "Party::claim: contribution already claimed"
        );
        // mark the contribution as claimed
        claimed[_contributor] = true;
        // calculate the amount of fractional NFT tokens owed to the user
        // based on how much ETH they contributed towards the party,
        // and the amount of excess ETH owed to the user
        (uint256 _tokenAmount, uint256 _ethAmount) = getClaimAmounts(
            _contributor
        );
        // transfer tokens to contributor for their portion of ETH used
        _transferTokens(_contributor, _tokenAmount);
        // if there is excess ETH, send it back to the contributor
        _transferETHOrWETH(_contributor, _ethAmount);
        emit Claimed(
            _contributor,
            totalContributed[_contributor],
            _ethAmount,
            _tokenAmount
        );
    }

    // ======== External: Emergency Escape Hatches (PartyDAO Multisig Only) =========

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyWithdrawEth to withdraw
     * ETH stuck in the contract
     */
    function emergencyWithdrawEth(uint256 _value) external onlyPartyDAO {
        _transferETHOrWETH(partyDAOMultisig, _value);
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can use emergencyCall to call an external contract
     * (e.g. to withdraw a stuck NFT or stuck ERC-20s)
     */
    function emergencyCall(address _contract, bytes memory _calldata)
        external
        onlyPartyDAO
        returns (bool _success, bytes memory _returnData)
    {
        (_success, _returnData) = _contract.call(_calldata);
        require(_success, string(_returnData));
    }

    /**
     * @notice Escape hatch: in case of emergency,
     * PartyDAO can force the Party to finalize with status LOST
     * (e.g. if finalize is not callable)
     */
    function emergencyForceLost() external onlyPartyDAO {
        // set partyStatus to LOST
        partyStatus = PartyStatus.LOST;
    }

    // ======== Public: Utility Calculations =========

    /**
     * @notice Convert ETH value to equivalent token amount
     */
    function valueToTokens(uint256 _value)
        public
        pure
        returns (uint256 _tokens)
    {
        _tokens = _value * TOKEN_SCALE;
    }

    /**
     * @notice The maximum amount that can be spent by the Party
     * while paying the ETH fee to PartyDAO
     * @return _maxSpend the maximum spend
     */
    function getMaximumSpend() public view returns (uint256 _maxSpend) {
        _maxSpend =
            (totalContributedToParty * 10000) /
            (10000 + ETH_FEE_BASIS_POINTS);
    }

    /**
     * @notice Calculate the amount of fractional NFT tokens owed to the contributor
     * based on how much ETH they contributed towards buying the token,
     * and the amount of excess ETH owed to the contributor
     * based on how much ETH they contributed *not* used towards buying the token
     * @param _contributor the address of the contributor
     * @return _tokenAmount the amount of fractional NFT tokens owed to the contributor
     * @return _ethAmount the amount of excess ETH owed to the contributor
     */
    function getClaimAmounts(address _contributor)
        public
        view
        returns (uint256 _tokenAmount, uint256 _ethAmount)
    {
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::getClaimAmounts: party still active; amounts undetermined"
        );
        uint256 _totalContributed = totalContributed[_contributor];
        if (partyStatus == PartyStatus.WON) {
            // calculate the amount of this contributor's ETH
            // that was used to buy the token
            uint256 _totalEthUsed = totalEthUsed(_contributor);
            if (_totalEthUsed > 0) {
                _tokenAmount = valueToTokens(_totalEthUsed);
            }
            // the rest of the contributor's ETH should be returned
            _ethAmount = _totalContributed - _totalEthUsed;
        } else {
            // if the token wasn't bought, no ETH was spent;
            // all of the contributor's ETH should be returned
            _ethAmount = _totalContributed;
        }
    }

    /**
     * @notice Calculate the total amount of a contributor's funds
     * that were used towards the buying the token
     * @dev always returns 0 until the party has been finalized
     * @param _contributor the address of the contributor
     * @return _total the sum of the contributor's funds that were
     * used towards buying the token
     */
    function totalEthUsed(address _contributor)
        public
        view
        returns (uint256 _total)
    {
        require(
            partyStatus != PartyStatus.ACTIVE,
            "Party::totalEthUsed: party still active; amounts undetermined"
        );
        // load total amount spent once from storage
        uint256 _totalSpent = totalSpent;
        // get all of the contributor's contributions
        Contribution[] memory _contributions = contributions[_contributor];
        for (uint256 i = 0; i < _contributions.length; i++) {
            // calculate how much was used from this individual contribution
            uint256 _amount = _ethUsed(_totalSpent, _contributions[i]);
            // if we reach a contribution that was not used,
            // no subsequent contributions will have been used either,
            // so we can stop calculating to save some gas
            if (_amount == 0) break;
            _total = _total + _amount;
        }
    }

    // ============ Internal ============

    function _closeSuccessfulParty(uint256 _nftCost)
        internal
        returns (uint256 _ethFee)
    {
        // calculate PartyDAO fee & record total spent
        _ethFee = _getEthFee(_nftCost);
        totalSpent = _nftCost + _ethFee;
        // transfer ETH fee to PartyDAO
        _transferETHOrWETH(partyDAOMultisig, _ethFee);
        // deploy fractionalized NFT vault
        // and mint fractional ERC-20 tokens
        _fractionalizeNFT(_nftCost);
    }

    /**
     * @notice Calculate ETH fee for PartyDAO
     * NOTE: Remove this fee causes a critical vulnerability
     * allowing anyone to exploit a Party via price manipulation.
     * See Security Review in README for more info.
     * @return _fee the portion of _amount represented by scaling to ETH_FEE_BASIS_POINTS
     */
    function _getEthFee(uint256 _amount) internal pure returns (uint256 _fee) {
        _fee = (_amount * ETH_FEE_BASIS_POINTS) / 10000;
    }

    /**
     * @notice Calculate token amount for specified token recipient
     * @return _totalSupply the total token supply
     * @return _partyDAOAmount the amount of tokens for partyDAO fee,
     * which is equivalent to TOKEN_FEE_BASIS_POINTS of total supply
     * @return _splitRecipientAmount the amount of tokens for the token recipient,
     * which is equivalent to splitBasisPoints of total supply
     */
    function _getTokenInflationAmounts(uint256 _amountSpent)
        internal
        view
        returns (
            uint256 _totalSupply,
            uint256 _partyDAOAmount,
            uint256 _splitRecipientAmount
        )
    {
        // the token supply will be inflated to provide a portion of the
        // total supply for PartyDAO, and a portion for the splitRecipient
        uint256 inflationBasisPoints = TOKEN_FEE_BASIS_POINTS +
            splitBasisPoints;
        _totalSupply = valueToTokens(
            (_amountSpent * 10000) / (10000 - inflationBasisPoints)
        );
        // PartyDAO receives TOKEN_FEE_BASIS_POINTS of the total supply
        _partyDAOAmount = (_totalSupply * TOKEN_FEE_BASIS_POINTS) / 10000;
        // splitRecipient receives splitBasisPoints of the total supply
        _splitRecipientAmount = (_totalSupply * splitBasisPoints) / 10000;
    }

    /**
     * @notice Query the NFT contract to get the token owner
     * @dev nftContract must implement the ERC-721 token standard exactly:
     * function ownerOf(uint256 _tokenId) external view returns (address);
     * See https://eips.ethereum.org/EIPS/eip-721
     * @dev Returns address(0) if NFT token or NFT contract
     * no longer exists (token burned or contract self-destructed)
     * @return _owner the owner of the NFT
     */
    function _getOwner() internal view returns (address _owner) {
        (bool _success, bytes memory _returnData) = address(nftContract)
            .staticcall(abi.encodeWithSignature("ownerOf(uint256)", tokenId));
        if (_success && _returnData.length > 0) {
            _owner = abi.decode(_returnData, (address));
        }
    }

    /**
     * @notice Upon winning the token, transfer the NFT
     * to fractional.art vault & mint fractional ERC-20 tokens
     */
    function _fractionalizeNFT(uint256 _amountSpent) internal {
        // approve fractionalized NFT Factory to withdraw NFT
        nftContract.approve(address(tokenVaultFactory), tokenId);
        // Party "votes" for a reserve price on Fractional
        // equal to 2x the price of the token
        uint256 _listPrice = RESALE_MULTIPLIER * _amountSpent;
        // users receive tokens at a rate of 1:TOKEN_SCALE for each ETH they contributed that was ultimately spent
        // partyDAO receives a percentage of the total token supply equivalent to TOKEN_FEE_BASIS_POINTS
        // splitRecipient receives a percentage of the total token supply equivalent to splitBasisPoints
        (
            uint256 _tokenSupply,
            uint256 _partyDAOAmount,
            uint256 _splitRecipientAmount
        ) = _getTokenInflationAmounts(totalSpent);
        // deploy fractionalized NFT vault
        uint256 vaultNumber = tokenVaultFactory.mint(
            name,
            symbol,
            address(nftContract),
            tokenId,
            _tokenSupply,
            _listPrice,
            0
        );
        // store token vault address to storage
        tokenVault = ITokenVault(tokenVaultFactory.vaults(vaultNumber));
        // transfer curator to null address (burn the curator role)
        tokenVault.updateCurator(address(0));
        // transfer tokens to PartyDAO multisig
        _transferTokens(partyDAOMultisig, _partyDAOAmount);
        // transfer tokens to token recipient
        if (splitRecipient != address(0)) {
            _transferTokens(splitRecipient, _splitRecipientAmount);
        }
    }

    // ============ Internal: Claim ============

    /**
     * @notice Calculate the amount of a single Contribution
     * that was used towards buying the token
     * @param _contribution the Contribution struct
     * @return the amount of funds from this contribution
     * that were used towards buying the token
     */
    function _ethUsed(uint256 _totalSpent, Contribution memory _contribution)
        internal
        pure
        returns (uint256)
    {
        if (
            _contribution.previousTotalContributedToParty +
                _contribution.amount <=
            _totalSpent
        ) {
            // contribution was fully used
            return _contribution.amount;
        } else if (
            _contribution.previousTotalContributedToParty < _totalSpent
        ) {
            // contribution was partially used
            return _totalSpent - _contribution.previousTotalContributedToParty;
        }
        // contribution was not used
        return 0;
    }

    // ============ Internal: TransferTokens ============

    /**
     * @notice Transfer tokens to a recipient
     * @param _to recipient of tokens
     * @param _value amount of tokens
     */
    function _transferTokens(address _to, uint256 _value) internal {
        // skip if attempting to send 0 tokens
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if token amount to send is greater than contract balance,
        // send full contract balance
        uint256 _partyBalance = tokenVault.balanceOf(address(this));
        if (_value > _partyBalance) {
            _value = _partyBalance;
        }
        tokenVault.transfer(_to, _value);
    }

    // ============ Internal: TransferEthOrWeth ============

    /**
     * @notice Attempt to transfer ETH to a recipient;
     * if transferring ETH fails, transfer WETH insteads
     * @param _to recipient of ETH or WETH
     * @param _value amount of ETH or WETH
     */
    function _transferETHOrWETH(address _to, uint256 _value) internal {
        // skip if attempting to send 0 ETH
        if (_value == 0) {
            return;
        }
        // guard against rounding errors;
        // if ETH amount to send is greater than contract balance,
        // send full contract balance
        if (_value > address(this).balance) {
            _value = address(this).balance;
        }
        // Try to transfer ETH to the given recipient.
        if (!_attemptETHTransfer(_to, _value)) {
            // If the transfer fails, wrap and send as WETH
            weth.deposit{value: _value}();
            weth.transfer(_to, _value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    /**
     * @notice Attempt to transfer ETH to a recipient
     * @dev Sending ETH is not guaranteed to succeed
     * this method will return false if it fails.
     * We will limit the gas used in transfers, and handle failure cases.
     * @param _to recipient of ETH
     * @param _value amount of ETH
     */
    function _attemptETHTransfer(address _to, uint256 _value)
        internal
        returns (bool)
    {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = _to.call{value: _value, gas: 30000}("");
        return success;
    }
}
