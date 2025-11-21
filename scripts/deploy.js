// scripts/deploy.js

const { ethers } = require("hardhat");

async function main() {
    // 1. Get the Signer (Deployer/Admin)
    const [deployer] = await ethers.getSigners();
    const deployerAddress = deployer.address;

    console.log("-------------------------------------------------------");
    console.log("📦 Deploying SupplyChainTracker contract...");
    console.log(`👤 Deploying with account: ${deployerAddress}`);
    
    // The deployer will automatically become the DEFAULT_ADMIN_ROLE in the constructor.
    // The constructor accepts one argument: 'admin'. We pass the deployer's address.
    const constructorAdminAddress = deployerAddress;

    // 2. Deploy the Contract
    const SupplyChainTrackerFactory = await ethers.getContractFactory("SupplyChainTracker");
    
    // Deploying with the deployer's address as the initial admin
    const supplyChainTracker = await SupplyChainTrackerFactory.deploy(constructorAdminAddress);

    // Wait for the deployment transaction to be mined
    await supplyChainTracker.waitForDeployment();
    
    const contractAddress = await supplyChainTracker.getAddress();
    
    console.log(`\n✅ SupplyChainTracker deployed to: ${contractAddress}`);
    console.log(`Initial Admin (DEFAULT_ADMIN_ROLE): ${constructorAdminAddress}`);
    console.log("-------------------------------------------------------");

    // Optional: Log the Gas Cost of deployment
    // You'd typically need the transaction receipt for this in a more complex script.
    // console.log(`Gas used for deployment: ${receipt.gasUsed.toString()}`);

    // Optional: **Post-Deployment Setup**
    // Example: Granting roles to other hardcoded addresses (if needed immediately after deployment)
    /*
    console.log("\n⚙️ Post-Deployment Setup: Granting Initial Roles...");
    
    const initialManufacturer = "0x...AddressForManufacturer1...";
    const initialTransporter = "0x...AddressForTransporter1...";
    
    let tx = await supplyChainTracker.grantManufacturer(initialManufacturer);
    await tx.wait();
    console.log(`- Granted MANUFACTURER_ROLE to: ${initialManufacturer}`);

    tx = await supplyChainTracker.grantTransporter(initialTransporter);
    await tx.wait();
    console.log(`- Granted TRANSPORTER_ROLE to: ${initialTransporter}`);
    */
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

