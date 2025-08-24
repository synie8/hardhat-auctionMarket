// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {

    // 代币地址:预言机地址的映射  
    mapping (address tokenAdrr => address dataFeedAddr) public priceFeeds;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // 添加/更新价格源
    function setPriceFeed(address tokenAdrr, address dataFeedAddr) external onlyOwner {
        priceFeeds[tokenAdrr] = dataFeedAddr;
    }


    //获取价格
    function getPriceByPair(address tokenAdrr) external view returns (int256) {

        address feedAddress = priceFeeds[tokenAdrr];
        require(feedAddress != address(0), "Price feed not configured");
        
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }
}