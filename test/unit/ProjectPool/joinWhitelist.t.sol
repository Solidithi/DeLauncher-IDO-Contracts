// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ProjectPool} from "../../../contracts/ProjectPool.sol"; // Adjust the path to your contract
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

struct MockAccount {
    uint256 privateKey;
    address accountAddr;
}

contract JoinWhiteListTest is Test, Script {
    // test props
    ProjectPool pool;
    ProjectPoolFactory factory;
    ProjectPoolTestUtil testUtil;
    ProjectPool.ProjectDetail pr;
    address mockSlpxAddr = address(0x01);

    constructor() {
        testUtil = new ProjectPoolTestUtil();
        factory = new ProjectPoolFactory(mockSlpxAddr);
    }

    function setUp() public {
        pool = testUtil.createTestProjectPool(factory);
        pr = pool.getProjectDetail();
    }

    function test_RevertIf_IDOHasEnded() external {
        uint256 rightNow = block.timestamp;
        uint256 afterProjectEnd = pr.endTime + 5 minutes;

        // manipulate block timestamp
        vm.warp(afterProjectEnd);

        // assertion
        vm.expectRevert(ProjectPool.ProjectIDOHasEnded.selector);
        pool.joinWhitelist();

        // reset timestamp
        vm.warp(rightNow);
    }

    function test_RevertIf_IDOHasNotStarted() external {
        uint256 rightNow = block.timestamp;

        // manipulate block timestamp to create test pool in the future
        uint256 fiveMinsLater = rightNow + 5 hours;
        vm.warp(fiveMinsLater);
        ProjectPool poolFromFuture = testUtil.createTestProjectPool(factory);
        address vAsset = poolFromFuture.getAcceptedVAsset();
        uint256 reserveAmount = poolFromFuture.getReserveInvestment();
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        MockVToken(vAsset).approve(address(poolFromFuture), reserveAmount);

        // warp back to present
        vm.warp(rightNow);

        // assertion
        vm.expectRevert(ProjectPool.ProjectIDOHasNotStarted.selector);
        poolFromFuture.joinWhitelist();
    }

    function test_StatesUpdatedCorrectly_IfSucceed() external {
        address vAsset = pool.getAcceptedVAsset();
        uint256 reserveAmount = pool.getReserveInvestment();
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        MockVToken(vAsset).approve(address(pool), reserveAmount);
        pool.joinWhitelist();

        // read post-update states
        uint256 userDepositAmount = pool.getUserDepositAmount(address(this));
        bool isWhitelisted = pool.isWhitelisted(address(this));
        uint256 projectRaisedAmount = pool.getProjectRaisedAmount(); // this should be unchanged

        // assertion
        assertEq(userDepositAmount, reserveAmount);
        assertEq(isWhitelisted, true);
        assertEq(projectRaisedAmount, 0);
    }

    function test_EmitWhitelistedEvent_IfSucceed() external {
        address vAsset = pool.getAcceptedVAsset();
        uint256 reserveAmount = pool.getReserveInvestment();
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        MockVToken(vAsset).approve(address(pool), reserveAmount);

        // assertion
        vm.expectEmit(true, true, false, false);
        emit ProjectPool.Whitelisted(address(this), pr.projectId);
        pool.joinWhitelist();
    }

	function test_RevertIf_AlreadyWhitelisted() external {
		testUtil.whitelistUser(pool, address(this));

		// assertion 
		vm.expectRevert(ProjectPool.AlreadyWhitelisted.selector);
		testUtil.whitelistUser(pool, address(this));
	}

    function test_RevertIf_HardCapExceeded() external {
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

		address investor1 = address(this);
        testUtil.whitelistUser(customPool, investor1);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor1);
		testUtil.userInvest(customPool, investor1, amountToReachMaxInvest);	

		// assertion
		address investor2 = vm.addr(0x02);	
		vm.startPrank(investor2);
		vm.expectRevert(ProjectPool.HardCapExceeded.selector);
		customPool.joinWhitelist();
    }
}
