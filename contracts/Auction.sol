// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ComprehensiveNFT.sol";
import "./PriceOracle.sol";

contract Auction {

    using SafeERC20 for IERC20;

    struct NftInfo {
        //nft所有者地址
        address ownerAddr;
        //起始价格
        uint256 startPrice;
        //当前价格-计价美元USD价格
        uint256 currentPrice;
        //当前竞拍人地址
        address bidder;
        //开始时间
        uint256 startTime;
        //结束时间
        uint256 endTime;
        //是否有人竞价
        bool hasBid;
    }

    struct BidInfo {
        //竞拍人地址
        address bidder;
        //竞拍金额ERC20代币数量
        uint256 erc20Balance;
        //竞拍金额ETH
        uint256 usdPrice;
        //竞拍时间
        uint256 bidTime;
        //竞拍总金额USD价格
        uint256 usdPrice;

    }

    // 拍卖的NFT
    mapping (uint256 tokenId => NftInfo owner) public nfts;
    //NFT竞价信息
    mapping (uint256 tokenId => mapping(address bidderAddr =>uint256 bidPrice )) public bidMapping;

    // 记录竞拍者的代币余额
    mapping(address bidder => mapping(address tokenAddress => uint256 amount )) public tokenBalances;

    //NFT合约
    ComprehensiveNFT public nft;
    //价格合约
    PriceOracle public priceOracle;

    constructor(address nftAddr,address priceOracleAddr) { 
        nft =  ComprehensiveNFT(nftAddr);
        priceOracle = PriceOracle(priceOracleAddr);
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
    //下架拍卖
    function cancelAuction(uint256 tokenId) public { 
        require(nfts[tokenId].owner==msg.sender, "You are not the owner of this NFT");
        require(!nfts[tokenId].isSold, "NFT has been sold");
        //将NFT转移给合约地址
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
        delete nfts[tokenId];

        emit AuctionEnd(msg.sender,tokenId,block.timestamp);
    }
    //转美元USD价格
    function convertToUSD(string calldata pair ,uint256 amount) internal returns(uint256) {
        uint256 price = priceOracle.getPriceByPair(pair);
        
        //转换成美元USD价格
        return uint256(price*amount/1e8);
    }

    //竞拍,接收ERC20代币
    function bidWithERC20(address tokenAddress,uint256 tokenId, uint256 bidPrice) public { 
        require(nfts[tokenId].isSold == false, "NFT has been sold");
        require(block.timestamp < nfts[tokenId].endTime, "Auction has ended");
        require(msg.sender !=nfts[tokenId].ownerAddr, "You cannot bid on your own NFT");
        //获取代币名称
        string memory tokenName = nfts[tokenId].tokenName;
        //转美元USD价格
        uint256 bidSum = bidMapping[tokenId][msg.sender]+msg.value;
        uint256 usdPrice = convertToUSD(bidSum);
        require(usdPrice > nfts[tokenId].currentPrice, "Bid must be higher than current price");
        //转账
        _receiveTokens(tokenAddress,bidPrice);
        //更新当前价格
        nfts[tokenId].currentPrice = usdPrice;
        nfts[tokenId].hasBid = true;
        nfts[tokenId].bidder = msg.sender;
        //更新竞拍者信息,可多次加价
        bidMapping[tokenId][msg.sender]+=msg.value;
        emit Bid(msg.sender, tokenId, bidPrice);

    }

    //竞拍,接收以太币
    function bid(uint256 tokenId) public payable { 
        require(nfts[tokenId].isSold == false, "NFT has been sold");
        require(block.timestamp < nfts[tokenId].endTime, "Auction has ended");
        require(msg.sender !=nfts[tokenId].ownerAddr, "You cannot bid on your own NFT");
        require(msg.value+bidMapping[tokenId][msg.sender] > nfts[tokenId].currentPrice, "Bid must be higher than current price");
        //转美元USD价格
        uint256 bidSum = bidMapping[tokenId][msg.sender]+msg.value;
        uint256 usdPrice = convertToUSD(bidSum);
        require(usdPrice > nfts[tokenId].currentPrice, "Bid must be higher than current price");
        //更新当前价格
        nfts[tokenId].currentPrice = msg.value;
        nfts[tokenId].hasBid = true;
        nfts[tokenId].bidder = msg.sender;
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
        delete bidMapping[tokenId][nfts[tokenId].bidder];

        emit AuctionEnd(msg.sender,tokenId,block.timestamp);
         
    }

    
    // 接收ERC20代币的核心方法
    function _receiveTokens(
        address tokenAddress,
        uint256 amount
    ) internal {
        IERC20 token = IERC20(tokenAddress);
        
        // 安全转账
        token.safeTransferFrom(msg.sender, address(this), amount);

        tokenBalances[msg.sender][tokenAddress] += amount;

  
    }

    // 提取代币的方法
    function _withdrawTokens(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        tokenBalances[msg.sender][tokenAddress] -= amount;

        IERC20(tokenAddress).safeTransfer(to, amount);
        
    }

    reveive() external payable{}

    fallback() external payable{}

}