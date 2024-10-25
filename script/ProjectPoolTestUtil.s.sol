// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProjectPool} from "../contracts/ProjectPool.sol";
import {ProjectPoolFactory} from "../contracts/ProjectPoolFactory.sol";
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

contract MockVTokenButReturnFalseOnTransfer is ERC20 {
    constructor() ERC20("vToken", "VT") {
		_mint(_msgSender(), 100000000000);
    }

	function freeMoneyForEveryone(address receiver, uint256 amount) public {
		_mint(receiver, amount);
	}
    function transfer(address, uint256) public pure override returns (bool) {
        return false;
    }
}

contract ProjectPoolTestUtil is Script {
    MockProjectToken projectToken;
    MockVToken vToken;

    constructor() {
        // do sth fun
        projectToken = new MockProjectToken();
        vToken = new MockVToken();
    }

    function createTestProjectPool(ProjectPoolFactory factory) public returns (ProjectPool) {
        address tokenAddress = address(projectToken); // Replace with actual token address
        uint256 projectTokenPrice = 1; // 1 project token is equal to exactly 1 vToken, for simplicity
        uint256 startTime = block.timestamp; // Start now
        uint256 endTime = startTime + 1 minutes; // End in 1 min
        uint256 minInvest = (1 * (10 ** vToken.decimals())) / 4; // Min invest: 0.25 vToken;
        uint256 maxInvest = 1 * (10 ** vToken.decimals()); // Max invest: 1 vToken
        uint256 hardCapAmount = 10000 * (10 ** vToken.decimals()); // Hard cap: 10000 vTokens
        uint256 softCapAmount = 1 * (10 ** vToken.decimals()); // Soft cap: 10 vTokens
        uint256 rewardRate = (1 * (10 ** 4)) / 10; // 0.1 (10%) reward rate
        address acceptedVAsset = address(vToken); // Replace with actual vAsset address

        // Call the addProject function
        uint256 projectId = factory.createProjectPool(
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
		address poolAddress = factory.getProjectPoolAddress(projectId);
		return ProjectPool(poolAddress);
    }

	function whitelistUser(ProjectPool pool, address user) public {
		vm.startPrank(user);
		address vAsset = pool.getAcceptedVAsset();
        uint256 reserveAmount = pool.getReserveInvestment();
        MockVToken(vAsset).freeMoneyForEveryone(user, reserveAmount);
        MockVToken(vAsset).approve(address(pool), reserveAmount);
		pool.joinWhitelist();
		vm.stopPrank();
	}

	function userInvest(ProjectPool pool, address user, uint256 amount) public {
		vm.startPrank(user);
		address vAsset = pool.getAcceptedVAsset();
        MockVToken(vAsset).freeMoneyForEveryone(user, amount);
        MockVToken(vAsset).approve(address(pool), amount);
		pool.investProject(amount);
		vm.stopPrank();
	}
}

// contract PoolDeployContract {
//     ProjectPoolFactory public factory;
//     ProjectPool public pool;
//     address public owner;
//     bool public inReentrancy;

//     constructor(ProjectPoolFactory _factory) payable {
//         factory = _factory;
//         owner = msg.sender;
//     }

//     function createPool(
//         address tokenAddress,
//         uint256 pricePerToken,
//         uint256 startTime,
//         uint256 endTime,
//         uint256 minInvest,
//         uint256 maxInvest,
//         uint256 hardCapAmount,
//         uint256 softCapAmount,
//         uint256 rewardRate,
//         address acceptedVAsset
//     ) external {
//         uint256 poolId = factory.createProjectPool(
//             tokenAddress,
//             pricePerToken,
//             startTime,
//             endTime,
//             minInvest,
//             maxInvest,
//             hardCapAmount,
//             softCapAmount,
//             rewardRate,
//             acceptedVAsset
//         );
        
//         // Explicitly cast poolAddress to payable
//         address payable poolAddress = payable(factory.getProjectPoolAddress(poolId));
//         pool = ProjectPool(poolAddress); // Now the address is payable
//     }

//     function getPoolOwner() public view returns (address) {
//         return pool.getProjectOwner();
//     }

//     // Mark the withdraw function as payable
//     function withdraw() external payable {
//         pool.slpxWithdrawFund(); 
//     }

//     // Add a receive function to accept ETH
//     receive() external payable {}

//     // Optional: Fallback function if needed for other calls
//     fallback() external payable {}
// }
