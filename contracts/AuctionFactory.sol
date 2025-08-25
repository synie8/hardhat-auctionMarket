// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./Auction.sol";

contract AuctionFactory is OwnableUpgradeable {
    // 拍卖合约实现地址
    address public auctionImplementation;
    
    // 所有已创建的拍卖合约
    address[] public allAuctions;
    
    // 用户创建的拍卖合约
    mapping(address => address[]) public userAuctions;
    
    // 价格预言机地址
    address public priceOracle;

    event AuctionCreated(address indexed auctionAddress, address indexed creator);
    event ImplementationUpdated(address indexed newImplementation);


    constructor() {
        _disableInitializers();
    }
    
    function initialize(address _priceOracle, address _auctionImplementation) public initializer {
        __Ownable_init();
        priceOracle = _priceOracle;
        auctionImplementation = _auctionImplementation;
    }

    // 创建新的拍卖合约
    function createAuction() external returns (address) {
        // 部署新的代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            auctionImplementation,
            abi.encodeCall(Auction.initialize, (priceOracle))
        );

        address auctionAddress = address(proxy);
        
        // 添加到拍卖合约列表
        allAuctions.push(auctionAddress);
        userAuctions[msg.sender].push(auctionAddress);

        emit AuctionCreated(auctionAddress, msg.sender);
        
        return auctionAddress;
    }

    // 更新拍卖合约实现
    function updateImplementation(address _newImplementation) external onlyOwner {
        auctionImplementation = _newImplementation;
        emit ImplementationUpdated(_newImplementation);
    }

    // 获取所有拍卖合约
    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }

    // 获取用户创建的拍卖合约
    function getUserAuctions(address user) external view returns (address[] memory) {
        return userAuctions[user];
    }

    // 获取拍卖合约数量
    function getAuctionsCount() external view returns (uint256) {
        return allAuctions.length;
    }
}