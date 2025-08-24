// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ComprehensiveNFT is ERC721 , Ownable {

     uint256 private _tokenIdCounter;

    constructor() ERC721("ComprehensiveNFT", "CNFT") Ownable(msg.sender) {}

    // 铸造NFT
    function mint(address to) public onlyOwner{
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        _safeMint(to, tokenId);
    }

    // 转移NFT
    function safeTransfer(
        address from,
        address to,
        uint256 tokenId
    ) public {
        
        transferFrom(from, to, tokenId);
    }
}