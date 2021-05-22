// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

abstract contract ERC20 {
    // ============ Public Constants ============

    // solhint-disable-next-line const-name-snakecase
    uint8 public constant decimals = 18;

    // ============ Public Mutable Storage ============

    string public name;
    string public symbol;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    // ============ Events ============

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    //======== Constructor =========

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // ============ External ============

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        _transfer(from, to, value);
        return true;
    }

    // ============ Internal ============

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value;
        totalSupply = totalSupply - value;
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        balanceOf[from] = balanceOf[from] - value;
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }
}
