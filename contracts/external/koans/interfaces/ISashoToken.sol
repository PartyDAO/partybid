pragma solidity ^0.8.6;

import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ISashoToken is IERC20 {

    function mint(address account, uint256 rawAmount) external;

    function burn(uint256 tokenId) external;

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint nonce, uint expiry, uint8 v, bytes32 r, bytes32 s) external;

    function setMinter(address minter) external;

    function lockMinter() external;

    function getCurrentVotes(address account) external view returns (uint96);

    function getPriorVotes(address account, uint blockNumber) external view returns (uint96);
}
