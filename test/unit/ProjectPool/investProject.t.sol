// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {ProjectPool} from "../../../contracts/ProjectPool.sol"; // Adjust the path to your contract
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

contract InvestProjectTest is Test {
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
        uint256 amount = 1;
        vm.expectRevert(ProjectPool.ProjectIDOHasEnded.selector);
        pool.investProject(amount);

        // reset timestamp
        vm.warp(rightNow);
    }

    function test_RevertIf_IDOHasNotStarted() external {
        uint256 rightNow = block.timestamp;

        // manipulate block timestamp
        uint256 fiveMinsLater = rightNow + 5 minutes;
        vm.warp(fiveMinsLater);
        ProjectPool poolFromFuture = testUtil.createTestProjectPool(factory);
        vm.warp(rightNow);

        // assertion
        vm.expectRevert(ProjectPool.ProjectIDOHasNotStarted.selector);
        poolFromFuture.joinWhitelist();
    }

    function test_RevertIf_ReserveAmountNotReached() external {
        // assertion
        vm.expectRevert(ProjectPool.NotEnoughERC20Allowance.selector);
        pool.joinWhitelist();
    }

    function test_RevertIf_ReserveAmountNotReached2() external {
        address vAsset = pool.getAcceptedVAsset();
        uint256 reserveAmount = pool.getReserveInvestment();
        IERC20(vAsset).approve(address(pool), reserveAmount - 1);

        // assertion
        vm.expectRevert(ProjectPool.NotEnoughERC20Allowance.selector);
        pool.joinWhitelist();
    }

    function test_RevertIf_UserNotWhitelisted() external {
        address vAsset = pool.getAcceptedVAsset();
        uint256 reserveAmount = pool.getReserveInvestment();
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        MockVToken(vAsset).approve(address(pool), reserveAmount);

        // assertion
        uint256 moreThanMinInvest = pool.getProjectMinInvest() + 1;
        vm.expectRevert(ProjectPool.UserNotWhitelisted.selector);
        pool.investProject(moreThanMinInvest);
    }

    function test_RevertIf_MinInvestmentNotReached() external {
        testUtil.whitelistUser(pool, address(this));
        uint256 investedAmount = pool.getUserDepositAmount(address(this));
        uint256 amountToReachMinInvest = pool.getProjectMinInvest() -
            investedAmount;
        uint256 amountToNotReachMinInvest = amountToReachMinInvest - 1;

        // assertion
        vm.expectRevert(ProjectPool.MinInvestmentNotReached.selector);
        pool.investProject(amountToNotReachMinInvest);
    }

    function test_RevertIf_MaxInvestmentExceeded() external {
        testUtil.whitelistUser(pool, address(this));
        uint256 investedAmount = pool.getUserDepositAmount(address(this));
        uint256 amountToReachMaxInvest = pool.getProjectMaxInvest() -
            investedAmount;
        uint256 amountToExceedMaxInvest = amountToReachMaxInvest + 1;

        // assertion
        vm.expectRevert(ProjectPool.MaxInvestmentExceeded.selector);
        pool.investProject(amountToExceedMaxInvest);
    }

    function test_RevertIf_NotEnoughERC20_Allowance() external {
        uint256 amountWannaInvest = pr.maxInvest;
        uint256 reserveAmount = pool.getReserveInvestment();
        address vAsset = pool.getAcceptedVAsset();
        MockVToken(vAsset).freeMoneyForEveryone(
            address(this),
            amountWannaInvest
        );
        MockVToken(vAsset).approve(address(pool), reserveAmount);
        testUtil.whitelistUser(pool, address(this));

        // assertion
        uint256 amountLeft = amountWannaInvest - reserveAmount;
        vm.expectRevert(ProjectPool.NotEnoughERC20Allowance.selector);
        pool.investProject(amountLeft);
    }

    function test_UpdateState_IfSucceed() external {
        uint256 amountWannaInvest = pool.getProjectMaxInvest();
        testUtil.whitelistUser(pool, address(this));
        uint256 amountLeft = amountWannaInvest -
            pool.getUserDepositAmount(address(this));
        testUtil.userInvest(pool, address(this), amountLeft);

        // assertion
        uint256 raisedAmount = pool.getProjectRaisedAmount();
        uint256 userDepositAmount = pool.getUserDepositAmount(address(this));
        bool isWhitelisted = pool.isWhitelisted(address(this));
        assertEq(raisedAmount, amountWannaInvest);
        assertEq(userDepositAmount, amountWannaInvest);
        assertEq(isWhitelisted, true);
    }

    function test_vTokenBalanceOfContractIncrease_IfSucceed() external {
        uint256 amountWannaInvest = pool.getProjectMaxInvest();
        testUtil.whitelistUser(pool, address(this));
        uint256 amountLeft = amountWannaInvest -
            pool.getUserDepositAmount(address(this));
        testUtil.userInvest(pool, address(this), amountLeft);

        // assertion
        address vTokenAddr = pool.getAcceptedVAsset();
        uint256 poolVTokenBalance = MockVToken(vTokenAddr).balanceOf(
            address(pool)
        );
        assertEq(poolVTokenBalance, amountWannaInvest);
    }
}
