// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceOracle {

    // 代币符号:预言机地址的映射 如 sepolia ETH/USD:0x694AA1769357215DE4FAC081bf1f309aDC325306
    mapping (string pair => address dataFeedAddr) public priceFeeds;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    // 添加/更新价格源
    function setPriceFeed(string calldata pair, address dataFeedAddr) external onlyOwner {
        priceFeeds[pair] = dataFeedAddr;
    }


    // 根据代币符号获取价格
    function getPriceByPair(string calldata pair) external view returns (int256) {

        address feedAddress = priceFeeds[pair];
        require(feedAddress != address(0), "Price feed not configured");
        
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feedAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }
}