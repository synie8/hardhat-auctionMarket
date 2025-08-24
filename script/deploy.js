const {ethers,run ,network} = require('hardhat');

async function main() { 
    console.log("Deploying  contracts...");

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
    
    const feed1 = await priceOracle.priceFeeds("0x0000000000000000000000000000000000000000");
    const feed2 = await priceOracle.priceFeeds("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");
    console.log("Price feed for token 1:", feed1);
    console.log("Price feed for token 2:", feed2);

    /*
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
    */

    // Verify contracts on Etherscan if deploying to Sepolia
    if (network.name === "sepolia") {
        console.log("Verifying contracts on Etherscan...");
        
        console.log("wait for 3 confirmations")
        await priceOracle.deploymentTransaction().wait(3)
        console.log("verifying contract on etherscan...")
        await verify(priceOracleAddress, [])

    } else {
        console.log("Skipping verification - not on Sepolia network");
    }
    
    console.log("Deployment completed!");
    /*
    console.log({
        PriceOracle: priceOracleAddress,
        ComprehensiveNFT: comprehensiveNFTAddress,
        AuctionFactory: auctionFactoryAddress,
        AuctionImplementation: auctionImplAddress
    });
    */
}
async function verify(address, args) {
  await hre.run("verify:verify", {
    address: address,
    constructorArguments: args,
  });
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });