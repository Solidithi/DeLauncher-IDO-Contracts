import { ethers } from "hardhat";

async function main() {
    const stdRefAddress = "0x2Bf9a731f9A56C59DeB4DF1369286A3E69F5b418";

    const DoubleOracle = await ethers.getContractFactory("DoubleOracle");

    const doubleOracle = await DoubleOracle.deploy(stdRefAddress);

    await doubleOracle.waitForDeployment();

    console.log("DoubleOracle deployed to:", await doubleOracle.getAddress());
}

main().catch((error) => {
    console.error("Error deploying contract:", error);
    process.exitCode = 1;
});
