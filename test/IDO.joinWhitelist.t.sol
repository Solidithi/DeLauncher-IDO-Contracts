// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IDO} from "../contracts/IDO.sol"; // Adjust the path to your contract
import {console} from "forge-std/console.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IDOTestUtil} from "../script/IDOTestUtil.s.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {MockProjectToken} from "../script/IDOTestUtil.s.sol";
import {MockVToken} from "../script/IDOTestUtil.s.sol";

struct MockAccount {
    uint256 privateKey;
    address accountAddr;
}

contract JoinWhiteListTest is Test {
    IDO ido;
    IDOTestUtil testUtil;
    address mockSlpxAddr = address(0);

    constructor() {
        testUtil = new IDOTestUtil();
    }

    function setUp() public {
        ido = new IDO(mockSlpxAddr);
    }

    function test_RevertIf_ProjectIdInvalId() external {
        uint256 currPID = ido.getCurrentProjectId();
        uint256 invalidPID = currPID + 1;

        // PID cannot be larger than currentPID
        vm.expectRevert(IDO.InvalidProjectId.selector);
        ido.joinWhitelist(invalidPID);

        // PID cannot be <= 0
        invalidPID = 0;
        vm.expectRevert(IDO.InvalidProjectId.selector);
        ido.joinWhitelist(invalidPID);
    }

    function test_RevertIf_IDOHasEnded() external {
        IDO.Project memory pr = testUtil.addTestProject(ido);
        uint256 rightNow = block.timestamp;
        uint256 afterProjectEnd = pr.endTime + 5 minutes;

        // manipulate block timestamp
        vm.warp(afterProjectEnd);

        // assertion
        vm.expectRevert(IDO.ProjectIDOHasEnded.selector);
        ido.joinWhitelist(pr.projectId);

        // reset timestamp
        vm.warp(rightNow);
    }

    function test_RevertIf_IDOHasNotStarted() external {
        uint256 rightNow = block.timestamp;

        // manipulate block timestamp
        uint256 fiveMinsLater = rightNow + 5 minutes;
        vm.warp(fiveMinsLater);
        IDO.Project memory pr = testUtil.addTestProject(ido);
        vm.warp(rightNow);

        // assertion
        vm.expectRevert(IDO.ProjectIDOHasNotStarted.selector);
        ido.joinWhitelist(pr.projectId);

        // reset timestamp
        vm.warp(rightNow);
    }

    function test_RevertIf_ReserveAmountNotReached() external {
        IDO.Project memory pr = testUtil.addTestProject(ido);

        // assertion
        vm.expectRevert(IDO.NotEnoughERC20Allowance.selector);
        ido.joinWhitelist(pr.projectId);
    }

    function test_RevertIf_ReserveAmountNotReached2() external {
        IDO.Project memory pr = testUtil.addTestProject(ido);
        address vAsset = ido.getAcceptedVAsset(pr.projectId);
        uint256 reserveAmount = ido.getReserveInvestment(pr.projectId);
        IERC20(vAsset).approve(address(ido), reserveAmount - 1);

        // assertion
        vm.expectRevert(IDO.NotEnoughERC20Allowance.selector);
        ido.joinWhitelist(pr.projectId);
    }

    function test_StatesUpdatedCorrectly_IfSucceed() external {
        IDO.Project memory pr = testUtil.addTestProject(ido);
        address vAsset = ido.getAcceptedVAsset(pr.projectId);
        uint256 reserveAmount = ido.getReserveInvestment(pr.projectId);
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        IERC20(vAsset).approve(address(ido), reserveAmount);
        ido.joinWhitelist(pr.projectId);

        // read post-update states
        uint256 investedAmount = ido.getInvestedAmount(
            pr.projectId,
            address(this)
        );
        bool isWhitelisted = ido.isWhitelisted(pr.projectId, address(this));
        uint256 projectRaisedAmount = ido.getProjectRaisedAmount(pr.projectId);

        // assertion
        assertEq(investedAmount, reserveAmount);
        assertEq(isWhitelisted, true);
        assertEq(projectRaisedAmount, reserveAmount);
    }

    function test_EmitWhitelistedEvent_IfSucceed() external {
        IDO.Project memory pr = testUtil.addTestProject(ido);
        address vAsset = ido.getAcceptedVAsset(pr.projectId);
        uint256 reserveAmount = ido.getReserveInvestment(pr.projectId);
        MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
        IERC20(vAsset).approve(address(ido), reserveAmount);

        // assertion
        vm.expectEmit(true, true, false, false);
        emit IDO.Whitelisted(address(this), pr.projectId);
        ido.joinWhitelist(pr.projectId);
    }
}
