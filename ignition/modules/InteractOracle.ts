import { ethers } from "hardhat"

async function main() {
    const OracleContract = "0xC3561a1bd2428e7E1886a051Ea26EceAb438Deb1";
    const DoubleOracle = await ethers.getContractAt("DoubleOracle", OracleContract);
    console.log("Oracle interacting Contract...");
    const transactionResponse = await DoubleOracle.getMultiPrices();
    console.log("Pairs price:", transactionResponse);
    console.log("Success!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

