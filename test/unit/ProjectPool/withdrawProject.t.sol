// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ProjectPool} from "../../../contracts/ProjectPool.sol"; // Adjust the path to your contract
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken, MockVTokenButReturnFalseOnTransfer, AttackerContract} from "../../../script/ProjectPoolTestUtil.s.sol";
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/interfaces/draft-IERC6093.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {Script} from "forge-std/Script.sol";

contract WithdrawTest is Test, Script {
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

    function _getCustomPool(
        MockProjectToken projectToken,
        MockVToken vToken
    ) internal returns (uint256) {
        address tokenAddress = address(projectToken); // Replace with actual token address
        uint256 pricePerToken = 1; // 1 project token is equal to exactly 1 vToken, for simplicity
        uint256 startTime = block.timestamp; // Start now
        uint256 endTime = startTime + 1 minutes; // End in 1 min
        uint256 minInvest = (1 * (10 ** vToken.decimals())) / 4; // Min invest: 0.25 vToken;
        uint256 maxInvest = 10 * (10 ** vToken.decimals()); // Max invest: 10 vToken
        // uint256 hardCapAmount = 10000 * (10 ** vToken.decimals()); // Hard cap: 10000 vTokens
        uint256 hardCapAmount = maxInvest * 10000;
        // uint256 softCapAmount = 1 * (10 ** vToken.decimals()); // Soft cap: 10 vTokens
        uint256 softCapAmount = maxInvest;
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

        return customProjectId;
    }

    function test_POBalanceAfterWithdraw() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 maxInvest = customPool.getProjectMaxInvest() * 10; 	
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVToken(vToken).approve(address(customPool), maxInvest);
        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

        // console.log(customPool.getProjectRaisedAmount());
        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);
        uint256 withdrawAmount = customPool.getWithdrawAmount();
        uint256 POBalanceBefore = MockVToken(vToken).balanceOf(address(this));
        customPool.withdrawFund();
        uint256 POBalanceAfter = MockVToken(vToken).balanceOf(address(this));

		// assertion
        uint256 totalBal = POBalanceBefore + withdrawAmount;
        assertEq(totalBal, POBalanceAfter);
        vm.warp(rightNow);
    }

	function test_ProjectPoolBalanceAfterWithdraw() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 maxInvest = customPool.getProjectMaxInvest();	
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVToken(vToken).approve(address(customPool), maxInvest);
        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

        // console.log(customPool.getProjectRaisedAmount());
        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);
        uint256 withdrawAmount = customPool.getWithdrawAmount();
        uint256 PoolBalanceBefore = MockVToken(vToken).balanceOf(poolAddress);
        customPool.withdrawFund();
        uint256 PoolBalanceAfter = MockVToken(vToken).balanceOf(poolAddress);

		// asertion
        uint256 totalBal = PoolBalanceAfter + withdrawAmount;
        assertEq(totalBal, PoolBalanceBefore);
        vm.warp(rightNow);
	}

    function test_IfWithdrawBeforeIDOEnd() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 maxInvest = customPool.getProjectMaxInvest();	
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVToken(vToken).approve(address(customPool), maxInvest);
        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

		// asertion
        vm.expectRevert(ProjectPool.ProjectStillActive.selector);
        customPool.withdrawFund();
	}

    function test_IfProjectOwnerWithdrawMultipleTimes() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 maxInvest = customPool.getProjectMaxInvest();	
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVToken(vToken).approve(address(customPool), maxInvest);
        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);

        customPool.withdrawFund();

        uint256 projectBalanceAfterWithdraw = MockVToken(vToken).balanceOf(poolAddress);

		// asertion
        vm.expectRevert(abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        poolAddress,  
        projectBalanceAfterWithdraw,                            
        customPool.getWithdrawAmount()                       
        ));

        customPool.withdrawFund();

        // reset timestamp
        vm.warp(rightNow);
	}

    function test_WithdrawCallingButTransferReturnFailInsteadOfError() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVTokenButReturnFalseOnTransfer vToken = new MockVTokenButReturnFalseOnTransfer();

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

		address investor = address(0x001);
        MockVTokenButReturnFalseOnTransfer(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVTokenButReturnFalseOnTransfer(vToken).approve(address(customPool), maxInvest);

        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);

        // assertion
        vm.expectRevert(ProjectPool.ERC20TransferFailed.selector);
        customPool.withdrawFund();
		
        // reset timestamp
        vm.warp(rightNow);
	}

    function test_NotProjectOwnerCallingWithdraw() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 maxInvest = customPool.getProjectMaxInvest();	
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);
        MockVToken(vToken).approve(address(customPool), maxInvest);
        testUtil.whitelistUser(customPool, investor);
        uint256 amountToReachMaxInvest = customPool.getProjectMaxInvest() -
            customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToReachMaxInvest);

        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);

		// asertion
        vm.expectRevert(ProjectPool.NotProjectOwner.selector);
        vm.prank(investor);
        customPool.withdrawFund();

        // reset timestamp
        vm.warp(rightNow);
	}

    function test_WithdrawWhenSoftCapNotReach() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        uint256 customProjectId = _getCustomPool(projectToken, vToken);
        address poolAddress = factory.getProjectPoolAddress(customProjectId);
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x01);
		uint256 invest = customPool.getProjectMinInvest();
        MockVToken(vToken).freeMoneyForEveryone(investor, invest);
        MockVToken(vToken).approve(address(customPool), invest);
        testUtil.whitelistUser(customPool, investor);
        uint256 whatUserHaveLeft = invest - customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, whatUserHaveLeft);

        uint256 rightNow = block.timestamp;
        uint256 timetravel = rightNow + 2 minutes;
        vm.warp(timetravel);

		// asertion
        vm.expectRevert(ProjectPool.SoftCapNotReach.selector);

        customPool.withdrawFund();

        // reset timestamp
        vm.warp(rightNow);
	}

    function test_canWithDrawPreventReentrancy() external {
        MockProjectToken projectToken = new MockProjectToken();
        MockVToken vToken = new MockVToken();

        AttackerContract attacker = new AttackerContract(factory);
        attacker.createPool(
        address(projectToken),
            1,
            block.timestamp,
            block.timestamp + 1 minutes,
            (1 * (10 ** vToken.decimals())) / 4,  
            1 * (10 ** vToken.decimals()),      
            10000 * (10 ** vToken.decimals()),    
            1 * (10 ** vToken.decimals()),        
            (1 * (10 ** 4)) / 10,               
            address(vToken)
        );

        address poolOwner = attacker.getPoolOwner();
        assertEq(poolOwner, address(attacker), "Attacker should be the pool owner");

        uint256 maxInvest = attacker.pool().getProjectMaxInvest();

        address investor = address(0x01);
    
        MockVToken(vToken).freeMoneyForEveryone(investor, maxInvest);  
        MockVToken(vToken).approve(address(attacker.pool()), maxInvest);  
        testUtil.whitelistUser(attacker.pool(), investor);  
        uint256 amountToReachMaxInvest = attacker.pool().getProjectMaxInvest() - attacker.pool().getUserDepositAmount(investor);
        testUtil.userInvest(attacker.pool(), investor, amountToReachMaxInvest);  

        uint256 rightNow = block.timestamp;
        uint256 timeTravel = rightNow + 2 minutes;
        vm.warp(timeTravel);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        attacker.attackWithdraw();  

        // Reset timestamp 
        vm.warp(rightNow);
    }
}

