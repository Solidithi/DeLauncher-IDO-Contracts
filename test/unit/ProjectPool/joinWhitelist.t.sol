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
        uint256 investedAmount = pool.getInvestedAmount(address(this));
        bool isWhitelisted = pool.isWhitelisted(address(this));
        uint256 projectRaisedAmount = pool.getProjectRaisedAmount();

        // assertion
        assertEq(investedAmount, reserveAmount);
        assertEq(isWhitelisted, true);
        assertEq(projectRaisedAmount, reserveAmount);
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
}
