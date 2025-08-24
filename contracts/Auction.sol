// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./PriceOracle.sol";

contract Auction is Initializable, UUPSUpgradeable, OwnableUpgradeable {

    using SafeERC20 for IERC20;

    struct NftInfo {
        //nft所有者地址
        address ownerAddr;
        //nft地址
        address nftAddr;
        //起始价格
        uint256 startPrice;
        //最高价-计价美元USD价格
        uint256 highestBid;
        //竞拍人地址
        address highestBidder;
        //开始时间
        uint256 startTime;
        //结束时间
        uint256 endTime;
        //代币地址 0x 地址为 ETH  则为其他ERC20代币  
        address tokenAddr;
        //竞拍金额 ETH或ERC20代币
        uint256 bidAmount;
        //是否结束
        bool isEnd;
        //是否有人竞价
        bool hasBid;
    }


    // 拍卖的NFT
    mapping (uint256 tokenId => NftInfo owner) public nfts;


    //价格合约
    PriceOracle public priceOracle;
    // 工厂合约地址
    address public factory;

    constructor() {
        _disableInitializers();
    }

    function initialize(address priceOracleAddr ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        priceOracle = PriceOracle(priceOracleAddr);
        factory = msg.sender;
    }


    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    }

    event AuctionStart(address indexed auctioneer,uint256 tokenId, uint256 startTime);
    event AuctionEnd(address indexed auctioneer,uint256 tokenId, uint256 endTime);
    event Bid(address indexed bidder,uint256 tokenId, uint256 bidPrice);

    //上架拍卖
    function createAuction(address nftTokenAddr,uint256 tokenId, uint256 _startPrice, uint256 duration ) public  {
        
        //转移前需要授权
        ERC721 nftToken = ERC721(nftTokenAddr);
        //调用者必须是该NFT的主人
        require(nftToken.ownerOf(tokenId) == msg.sender, "You don't own this NFT!");
        //拍卖合约是否有权转移这个NFT
        require(
            nftToken.getApproved(tokenId) == address(this) ||
            nftToken.isApprovedForAll(msg.sender, address(this)),
            "Auction contract is not approved to manage this NFT!"
        );
        //转移NFT至当前合约地址
        nftToken.safeTransferFrom(msg.sender, address(this), tokenId);

        //初始化NFT信息
        nfts[tokenId] = NftInfo({
            ownerAddr: msg.sender,
            nftAddr: nftTokenAddr,
            startPrice: _startPrice,
            startTime: block.timestamp,
            endTime: block.timestamp+duration,
            highestBid: _startPrice,
            highestBidder: address(0),
            tokenAddr: address(0),
            bidAmount: 0,
            isEnd: false,
            hasBid: false
        });

        emit AuctionStart(msg.sender,tokenId,block.timestamp);

    }

    //转美元USD价格
    function convertToUSD(address tokenAddress ,uint256 amount) internal view returns(uint256) {
        uint256 price = uint256(priceOracle.getPriceByPair(tokenAddress));
        
        //转换成美元USD价格
        return uint256(price*amount/1e8);
    }


    //竞拍,接收以太币或者ERC20代币
    function bid(uint256 nftTokenId,uint256 amount,address tokenAddress) public payable { 
        //如果 tokenAddress为0x0,则接收ETH
        bool isETH = tokenAddress == address(0x0) ;
        uint256 _bidAmount = isETH ? msg.value : amount; 
        //转美元USD价格
        uint256 usdPrice = convertToUSD(tokenAddress,_bidAmount);

        require(!nfts[nftTokenId].isEnd , "NFT has been sold");
        require(block.timestamp < nfts[nftTokenId].endTime , "Auction has ended");
        require(msg.sender !=nfts[nftTokenId].ownerAddr, "You cannot bid on your own NFT");
        require(usdPrice > nfts[nftTokenId].highestBid, "Bid must be higher than current price");

        //ERC20代币接收
        if (!isETH) {
            IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        }

        //退还上一个最高价
        bool isETHLast = nfts[nftTokenId].tokenAddr == address(0x0) ;
        if(isETHLast){
            // ETH退还
            payable(nfts[nftTokenId].highestBidder).transfer(nfts[nftTokenId].highestBid);
        }else{
            // ERC20退还
            IERC20(nfts[nftTokenId].tokenAddr).transfer(nfts[nftTokenId].highestBidder, nfts[nftTokenId].highestBid);
        }


        //更新当前价格
        nfts[nftTokenId].highestBid = usdPrice;
        nfts[nftTokenId].hasBid = true;
        nfts[nftTokenId].highestBidder = msg.sender;
        nfts[nftTokenId].tokenAddr = tokenAddress;
        nfts[nftTokenId].bidAmount = _bidAmount ;

        emit Bid(msg.sender, nftTokenId, amount);

    }


    //获取当前出价
    function getCurrentPrice(uint256 tokenId) public view returns(uint256) {
        return nfts[tokenId].highestBid;
    }
    
    //NFT拍卖结束
    function endAuction(uint256 tokenId) public {
        require(nfts[tokenId].ownerAddr==msg.sender || nfts[tokenId].highestBidder == msg.sender, "You are not the owner of this NFT or the highest bidder");
        require(nfts[tokenId].endTime<block.timestamp, "Auction has not ended yet");
        require(!nfts[tokenId].isEnd, "Auction has already been ended");
        
        if(nfts[tokenId].hasBid){
            //如果有人竞价
            //转账给拍卖者
            if(nfts[tokenId].tokenAddr == address(0)){  
                payable(nfts[tokenId].ownerAddr).transfer(nfts[tokenId].highestBid);
            }else{
                IERC20(nfts[tokenId].tokenAddr).safeTransfer(nfts[tokenId].ownerAddr, nfts[tokenId].highestBid);
            }
            //将NFT转移给最高价竞拍者
            IERC721(nfts[tokenId].nftAddr).safeTransferFrom(address(this), nfts[tokenId].highestBidder, tokenId);
        }else{
            //退还NFT给拍卖者
            IERC721(nfts[tokenId].nftAddr).safeTransferFrom(address(this), nfts[tokenId].ownerAddr, tokenId);
        }
    
        nfts[tokenId].isEnd = true;

        emit AuctionEnd(msg.sender,tokenId,block.timestamp);
         
    }

    

    receive() external payable{}

    fallback() external payable{}

}