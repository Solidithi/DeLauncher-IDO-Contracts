import { ethers } from "hardhat"

async function main() {
    const IDOadr = "0x9c0BF7CBfd599A017Ad76e28eBd094BC7F47F1c2";
    const IDO = await ethers.getContractAt("IDO", IDOadr);
    console.log("IDO Contract...");
    const transactionResponse = await IDO.getDeployer();
    console.log("Deployer Address:", transactionResponse);
    console.log("Success!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

