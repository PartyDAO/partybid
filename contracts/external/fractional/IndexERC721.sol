//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./OpenZeppelin/utils/Counters.sol";
import "./OpenZeppelin/token/ERC20/IERC20.sol";
import "./OpenZeppelin/token/ERC721/ERC721.sol";
import "./OpenZeppelin/token/ERC721/ERC721Holder.sol";

/**
 * Mint a single ERC721 which can hold NFTs
 */
contract IndexERC721 is ERC721, ERC721Holder {

    event Deposit(address indexed token, uint256 tokenId, address indexed from);

    event Withdraw(address indexed token, uint256 tokenId, address indexed to);

    event WithdrawETH(address indexed who);

    event WithdrawERC20(address indexed token, address indexed who);

    constructor() ERC721("NFT Basket", "NFTB") {
        _mint(msg.sender, 0);
    }

    /// @notice deposit an ERC721 token from another contract into an ERC721 in this contract
    /// @param _token the address of the NFT you are depositing
    /// @param _tokenId the ID of the NFT you are depositing
    function depositERC721(address _token, uint256 _tokenId) external {
        require(_token != address(this), "can't deposit self");
        IERC721(_token).safeTransferFrom(msg.sender, address(this), _tokenId);

        emit Deposit(_token, _tokenId, msg.sender);
    }

    /// @notice withdraw an ERC721 token from this contract into your wallet
    /// @param _token the address of the NFT you are withdrawing
    /// @param _tokenId the ID of the NFT you are withdrawing
    function withdrawERC721(address _token, uint256 _tokenId) external {
        require(_isApprovedOrOwner(msg.sender, 0), "withdraw:not allowed");

        IERC721(_token).safeTransferFrom(address(this), msg.sender, _tokenId);

        emit Withdraw(_token, _tokenId, msg.sender);
    }

    /// @notice withdraw ETH in the case a held NFT earned ETH (ie. euler beats)
    function withdrawETH() external {
        require(_isApprovedOrOwner(msg.sender, 0), "withdraw:not allowed");

        payable(msg.sender).transfer(address(this).balance);

        emit WithdrawETH(msg.sender);
    }

    /// @notice withdraw ERC20 in the case a held NFT earned ERC20
    function withdrawERC20(address _token) external {
        require(_isApprovedOrOwner(msg.sender, 0), "withdraw:not allowed");

        IERC20(_token).transfer(msg.sender, IERC20(_token).balanceOf(address(this)));

        emit WithdrawERC20(_token, msg.sender);
    }

    receive() external payable {}
}
