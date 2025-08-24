const { ethers, deployments, getNamedAccounts, network } = require("hardhat")
const {time,loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { assert, expect } = require("chai")

describe("Auction", function () {
      async function deploy() {
        
            console.log("Deploying PriceOracle...");
            const PriceOracle = await ethers.getContractFactory("PriceOracle");
            const priceOracle = await PriceOracle.deploy();
            await priceOracle.waitForDeployment();
            const priceOracleAddress = await priceOracle.getAddress();
            console.log(`PriceOracle deployed to ${priceOracleAddress}`);

            const priceOracleTx1 =  await priceOracle.setPriceFeed("0x0000000000000000000000000000000000000000", "0x694AA1769357215DE4FAC081bf1f309aDC325306");
            const priceOracleTx2 =  await priceOracle.setPriceFeed("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E");
            await priceOracleTx1.wait();
            await priceOracleTx2.wait();

            console.log("Deploying ComprehensiveNFT...");
            const ComprehensiveNFT = await ethers.getContractFactory("ComprehensiveNFT");
            const comprehensiveNFT = await ComprehensiveNFT.deploy();
            await comprehensiveNFT.waitForDeployment();
            const comprehensiveNFTAddress = await comprehensiveNFT.getAddress();
            console.log(`ComprehensiveNFT deployed to ${comprehensiveNFTAddress}`);

            console.log("Deploying Auction implementation...");
            const Auction = await ethers.getContractFactory("Auction");
            const auctionImpl = await Auction.deploy();
            await auctionImpl.waitForDeployment();
            const auctionImplAddress = await auctionImpl.getAddress();
            console.log("Auction implementation deployed to:", auctionImplAddress);

            console.log("Deploying AuctionFactory...");
            const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
            const auctionFactory = await AuctionFactory.deploy();
            await auctionFactory.waitForDeployment();
            const auctionFactoryAddress = await auctionFactory.getAddress();
            console.log("AuctionFactory deployed to:", auctionFactoryAddress);

            let firstAccount = (await getNamedAccounts()).firstAccount
            let secondAccount = (await getNamedAccounts()).secondAccount
            
            return { priceOracleAddress, comprehensiveNFTAddress, auctionImplAddress, auctionFactoryAddress, firstAccount,secondAccount };
      }
    
    it("test if the owner is msg.sender", async function() {

        const { firstAccount, priceOracleAddress } = await deploy();

        await assert.equal(priceOracleAddress.owner(), firstAccount)
    })


})