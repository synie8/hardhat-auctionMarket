// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ComprehensiveNFT.sol";

contract Auction {

    struct NftInfo {
        //nft所有者地址
        address ownerAddr;
        //起始价格
        uint256 startPrice;
        //当前价格
        uint256 currentPrice;
        //开始时间
        uint256 startTime;
        //结束时间
        uint256 endTime;
        //是否已售出
        bool isSold;
    }
    //竞拍信息结构体,可以多次竞拍同一个NFT
    struct BidInfo {
        //竞拍者地址
        address bidderAddr;
        //竞拍价格
        uint256 bidPrice;
    }

    // 拍卖的NFT
    mapping (uint256 tokenId => NftInfo owner) public nfts;
    //NFT竞拍信息
    mapping (uint256 tokenId => BidInfo[] bidInfos) public nfts;

    //NFT合约
    ComprehensiveNFT public nft;

    constructor(address nftAddr) { 
        nft = new ComprehensiveNFT(nftAddr);
    }

    //上架拍卖
    function listingAuction(uint256 tokenId, uint256 startPrice, uint256 endTime) public {
        require(endTime > block.timestamp, "endTime must be in the future");
        //转移NFT到该合约地址
        nft.safeTransferFrom(msg.sender, address(this), tokenId);


        nfts[tokenId] = NftInfo({
            ownerAddr: msg.sender,
            startPrice: startPrice,
            currentPrice: startPrice,
            startTime: block.timestamp,
            endTime: endTime,
            isSold: false
        });

    }

    //竞拍
    function bid(uint256 tokenId) public payable { 
        require(nfts[tokenId].isSold == false, "NFT has been sold");
        require(block.timestamp < nfts[tokenId].endTime, "Auction has ended");
        require(msg.value > nfts[tokenId].currentPrice, "Bid must be higher than current price");
        require(msg.sender !=nfts[tokenId].ownerAddr, "You cannot bid on your own NFT");
        //更新当前价格
        nfts[tokenId].currentPrice = msg.value;

    }
}