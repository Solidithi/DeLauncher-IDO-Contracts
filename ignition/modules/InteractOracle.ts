import { ethers } from "hardhat"

async function main() {
    const OracleContract = "0xfd489410090bE090597C791aC16e857D91718C92";

    const DoubleOracle = await ethers.getContractAt("DoubleOracle", OracleContract);

    console.log(`Interacting to oracle: ${OracleContract}`);

    const bases: string[] = ["WBTC", "ASTR", "DOT", "ASTR", "ASTR"];
    const quotes: string[] = ["USDT", "USDT", "USDT", "DOT", "USDC"];
    const transactionResponse = await DoubleOracle.getPrices(
        bases,
        quotes
    );

    for (let i = 0; i < transactionResponse.length; i++) {
        const PairRate = ethers.formatEther(transactionResponse[i]);
        console.log(`${bases[i]}/${quotes[i]}: ${PairRate}\n`);
    }

    const [price, latestBTC, latestUSDT] = await DoubleOracle.getPrice("WBTC", "USDT");

    const latestBTCUpdated = new Date(Number(latestBTC) * 1000);
    const latestUSDTUpdated = new Date(Number(latestUSDT) * 1000);

    console.log(`WBTC/USDT: ${ethers.formatEther(price)}`);
    console.log(`Latest BTC updated: ${latestBTCUpdated}`);
    console.log(`Latest USDT updated: ${latestUSDTUpdated}`);

    console.log("Success!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })

