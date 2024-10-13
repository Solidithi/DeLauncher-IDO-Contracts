// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ProjectPool} from "../../../contracts/ProjectPool.sol"; // Adjust the path to your contract
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract TestCreateProjectPool is Test {
    // test props
    ProjectPool pool;
    ProjectPoolFactory factory;
    ProjectPoolTestUtil testUtil;
    ProjectPool.ProjectDetail pr;
    address mockSlpxAddr = address(0x01);
    address testUtilAddr = vm.addr(1);
    address immutable txSender;

    constructor() {
        factory = new ProjectPoolFactory(mockSlpxAddr);
        vm.startPrank(testUtilAddr);
        testUtil = new ProjectPoolTestUtil();
        vm.stopPrank();
        txSender = msg.sender;
    }

    function setUp() public {
        pool = testUtil.createTestProjectPool(factory);
        pr = pool.getProjectDetail();
    }

    function test_ThisContractIsProjectOwner() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        address tokenAddress = address(projectToken); // Replace with actual token address
        uint256 pricePerToken = 1; // 1 project token is equal to exactly 1 vToken, for simplicity
        uint256 startTime = block.timestamp; // Start now
        uint256 endTime = startTime + 1 minutes; // End in 1 min
        uint256 minInvest = (1 * (10 ** vToken.decimals())) / 4; // Min invest: 0.25 vToken;
        uint256 maxInvest = 1 * (10 ** vToken.decimals()); // Max invest: 1 vToken
        // uint256 hardCapAmount = 10000 * (10 ** vToken.decimals()); // Hard cap: 10000 vTokens
        uint256 hardCapAmount = maxInvest;
        // uint256 softCapAmount = 1 * (10 ** vToken.decimals()); // Soft cap: 10 vTokens
        uint256 softCapAmount = minInvest;
        uint256 rewardRate = (1 * (10 ** 4)) / 10; // 0.1 (10%) reward rate
        address acceptedVAsset = address(vToken); // Replace with actual vAsset address

        uint256 customProjectId = factory.createProjectPool(
            tokenAddress,
            pricePerToken,
            startTime,
            endTime,
            minInvest,
            maxInvest,
            hardCapAmount,
            softCapAmount,
            rewardRate,
            acceptedVAsset
        );
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);
		
		// assertion
		address projectOwner = customPool.getProjectOwner();
		assertEq(address(this), projectOwner);
    }
}
