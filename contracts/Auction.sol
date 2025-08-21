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
        //是否有人竞价
        bool hasBid;
    }

    // 拍卖的NFT
    mapping (uint256 tokenId => NftInfo owner) public nfts;
    //NFT竞价信息
    mapping (uint256 tokenId => mapping(address bidderAddr =>uint256 bidPrice )) public bidMapping;

    //NFT合约
    ComprehensiveNFT public nft;

    constructor(address nftAddr) { 
        nft = new ComprehensiveNFT(nftAddr);
    }

    event AuctionStart(address auctioneer,uint256 tokenId, uint256 startTime);
    event AuctionEnd(address auctioneer,uint256 tokenId, uint256 endTime);
    event Bid(address bidder,uint256 tokenId, uint256 bidPrice);
    event Withdraw(address bidder,uint256 tokenId, uint256 bidPrice);

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
            hasBid: false
        });

        emit AuctionStart(msg.sender,tokenId,block.timestamp);

    }

    //竞拍
    function bid(uint256 tokenId) public payable { 
        require(nfts[tokenId].isSold == false, "NFT has been sold");
        require(block.timestamp < nfts[tokenId].endTime, "Auction has ended");
        require(msg.sender !=nfts[tokenId].ownerAddr, "You cannot bid on your own NFT");
        require(msg.value+bidMapping[tokenId][msg.sender] > nfts[tokenId].currentPrice, "Bid must be higher than current price");
        //更新当前价格
        nfts[tokenId].currentPrice = msg.value;
        nfts[tokenId].hasBid = true;
        //更新竞拍者信息,可多次加价
        bidMapping[tokenId][msg.sender]+=msg.value;

        emit Bid(msg.sender, tokenId, msg.value);

    }
    //竞拍结束，未竞拍到NFT的竞拍金额退回
    function withdrawBid(uint256 tokenId) public { 
        require(block.timestamp >= nfts[tokenId].endTime, "Auction has not ended");
        require(bidMapping[tokenId][msg.sender]>0, "You have not bid on this NFT");
        uint256 amount = bidMapping[tokenId][msg.sender];
        bidMapping[tokenId][msg.sender]=0;
        payable(msg.sender).transfer(amount);

        emit WithdrawBid(msg.sender, tokenId, amount);
    }

    
    //获取当前价格
    function getCurrentPrice(uint256 tokenId) public view returns(uint256) {
        return nfts[tokenId].currentPrice;
    }
    
    //NFT拍卖结束
    function endAuction(uint256 tokenId) public {
        require(nfts[tokenId].owner==msg.sender, "You are not the owner of this NFT");
        require(nfts[tokenId].endTime<block.timestamp, "Auction has not ended yet");
        
        if(nfts[tokenId].hasBid){
            //如果有人竞价
            //转账给拍卖者
            payable(nfts[tokenId].owner).transfer(nfts[tokenId].currentPrice);
            //将NFT转移给最高价竞拍者
            nft.safeTransferFrom(address(this), nfts[tokenId].bidder, tokenId);
        }else{
            //退还NFT给拍卖者
            nft.safeTransferFrom(address(this), nfts[tokenId].owner, tokenId);
        }
        delete nfts[tokenId];

        emit AuctionEnd(msg.sender,tokenId,block.timestamp);
         
    }

    reveive() external payable{}

    fallback() external payable{}

}