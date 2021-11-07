pragma solidity ^0.8.6;

import { IERC721 } from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface IKoansToken is IERC721 {
    event KoanCreated(uint256 indexed tokenId);

    event KoanBurned(uint256 indexed tokenId);

    event FoundersDAOUpdated(address koansDAO);

    event MinterUpdated(address minter);

    event MinterLocked();

    function setContractURIHash(string memory newContractURIHash) external;
    
    function setFoundersDAO(address _foundersDAO) external;

    function setMinter(address _minter) external;
    
    function lockMinter() external;

    function mintFoundersDAOKoan(string memory _foundersDAOMetadataURI) external;

    function mint() external returns (uint256);

    function burn(uint256 tokenId) external;

    function setMetadataURI(uint256 tokenId, string memory metadataURI) external;

}
