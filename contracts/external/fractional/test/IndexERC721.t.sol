//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ds-test/test.sol";

import "../IndexERC721.sol";
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

/// @author andy8052
/// @title Tests for the NFT index
contract IndexERC721Test is DSTest, ERC721Holder {
    Hevm public hevm;
    
    TestERC721 public token1;
    TestERC721 public token2;

    IndexERC721 public index;

    function setUp() public {
        // hevm "cheatcode", see: https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        index = new IndexERC721();

        token1 = new TestERC721();

        token2 = new TestERC721();

        token1.mint(address(this), 1);
        token1.mint(address(this), 2);
        token1.mint(address(this), 3);
        token1.mint(address(this), 4);

        token2.mint(address(this), 1);
        token2.mint(address(this), 2);
        token2.mint(address(this), 3);
        token2.mint(address(this), 4);


        token1.setApprovalForAll(address(index), true);
        token2.setApprovalForAll(address(index), true);
    }

    function test_integration() public {
        index.depositERC721(address(token1), 1);
        index.depositERC721(address(token1), 2);
        index.depositERC721(address(token2), 1);

        // we now have 3 tokens deposited
        assertTrue(token1.ownerOf(1) == address(index));

        index.withdrawERC721(address(token1), 1);
        index.withdrawERC721(address(token1), 2);
        index.withdrawERC721(address(token2), 1);

        assertTrue(token1.ownerOf(1) == address(this));

        uint256 bal = address(this).balance;

        payable(address(index)).transfer(10 ether);

        index.withdrawETH();

        assertEq(address(this).balance, bal);
    }

    receive() external payable {}
    
}