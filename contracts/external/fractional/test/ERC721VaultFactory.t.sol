//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../ERC721VaultFactory.sol";
import "./TestERC721.sol";

interface Hevm {
    function warp(uint256) external;

    function roll(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;
}

contract User {

    ERC721VaultFactory public factory;

    constructor(address _factory) {
        factory = ERC721VaultFactory(_factory);
    }

    // to be able to receive funds
    receive() external payable {} // solhint-disable-line no-empty-blocks
}

/// @author Nibble Market
/// @title Tests for the vault factory
contract VaultFactoryTest is DSTest {
    Hevm public hevm;
    
    ERC721VaultFactory public factory;
    TestERC721 public token;

    User public user1;
    User public user2;
    User public user3;

    function setUp() public {
        // hevm "cheatcode", see: https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // factory = new VaultFactory();

        // token = new TestERC721();

        // token.mint(address(this), 1);

        // // create 3 users and provide funds through HEVM store
        // user1 = new User(address(factory));
        // user2 = new User(address(factory));
        // user3 = new User(address(factory));
    }

}