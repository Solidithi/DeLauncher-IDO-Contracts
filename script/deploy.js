const { ethers } = require("ethers");
require('dotenv').config();
const data = require("../out/ProjectPoolFactory.sol/ProjectPoolFactory.json");

const privateKey = process.env.dev1Key;
const shibuyaRPC = process.env.SHIBUYA_RPC_URL;

const provider = new ethers.JsonRpcProvider(shibuyaRPC);
const wallet = new ethers.Wallet(privateKey, provider);

const abi = data.abi;
const bytecode = data.bytecode;

async function deployContract() {
    const ProjectPoolFactory = new ethers.ContractFactory(abi, bytecode, wallet);

    console.log("Deploying contract...");

    const contract = await ProjectPoolFactory.deploy(
        "0x2fD8bbF5dc8b342C09ABF34f211b3488e2d9d691" // slpx contract
    );

    // Wait for the contract to be mined
    await contract.waitForDeployment();

    console.log("Contract deployed at address:", await contract.getAddress());
}

deployContract()
    .then(() => console.log("Deployment successful"))
    .catch((error) => console.error("Deployment failed", error));
