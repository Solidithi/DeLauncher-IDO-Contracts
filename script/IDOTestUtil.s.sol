// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IDO} from "../contracts/IDO.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract MockProjectToken is ERC20 {
    constructor() ERC20("projectToken", "PT") {
        // do sth fun
		_mint(_msgSender(), 100000000000);
    }

	function freeMoneyForEveryone(address receiver, uint256 amount) public {
		_mint(receiver, amount);
	}
}

contract MockVToken is ERC20 {
    constructor() ERC20("vToken", "VT") {
        // do sth fun
		_mint(_msgSender(), 100000000000);
    }

	function freeMoneyForEveryone(address receiver, uint256 amount) public {
		_mint(receiver, amount);
	}
}

contract IDOTestUtil is Script {
    MockProjectToken projectToken;
    MockVToken vToken;

    constructor() {
        // do sth fun
        projectToken = new MockProjectToken();
        vToken = new MockVToken();
    }

    function addTestProject(IDO ido) public returns (IDO.Project memory) {
        address tokenAddress = address(projectToken); // Replace with actual token address
        uint256 projectTokenPrice = 1; // 1 project token is equal to exactly 1 vToken, for simplicity
        uint256 startTime = block.timestamp; // Start now
        uint256 endTime = startTime + 1 minutes; // End in 1 min
        uint256 minInvest = (1 * (10 ** vToken.decimals())) / 4; // Min invest: 0.25 vToken;
        uint256 maxInvest = 1 * (10 ** vToken.decimals()); // Max invest: 1 vToken
        uint256 hardCapAmount = 10000 * (10 ** vToken.decimals()); // Hard cap: 10000 vTokens
        uint256 softCapAmount = 1 * (10 ** vToken.decimals()); // Soft cap: 10 vTokens
        uint256 rewardRate = (1 * (10 ** ido.RATE_DECIMALS())) / 10; // 0.1 (10%) reward rate
        address acceptedVAsset = address(vToken); // Replace with actual vAsset address

        // Call the addProject function
        ido.addProject(
            tokenAddress,
            projectTokenPrice,
            startTime,
            endTime,
            minInvest,
            maxInvest,
            hardCapAmount,
            softCapAmount,
            rewardRate,
            acceptedVAsset
        );

        uint256 currPID = ido.getCurrentProjectId();
        // Return the newly created project
        return ido.getProjectFullDetails(currPID - 1); // Assuming the project ID is 1
    }

	// Trial run
    function run() external {
        IDO ido = new IDO(address(0));
        addTestProject(ido);
    }
}