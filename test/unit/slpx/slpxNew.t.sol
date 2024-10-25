// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProjectPool} from "../../../contracts/ProjectPool.sol"; 
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {MockSLPX} from "../../../script/slpx.s.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract TestSLPXWithdraw is Test {
    MockSLPX public mockSLPX;
    MockVToken public vToken;
    MockProjectToken public projectToken;
    ProjectPoolFactory public factory;
    uint256 public poolId;
    ProjectPool public pool;
    ProjectPoolTestUtil testUtil;
    address public user = address(0x456);

    function setUp() public {
        // Deploy contracts and initialize state
        vToken = new MockVToken();
        projectToken = new MockProjectToken(); 

        mockSLPX = new MockSLPX{value: 100 ether}(vToken);

        testUtil = new ProjectPoolTestUtil();
        
        factory = new ProjectPoolFactory(address(mockSLPX));
        poolId = factory.createProjectPool(
            address(projectToken), 
            1, 
            block.timestamp, 
            block.timestamp + 2 minutes, 
            1 ether,
            10 ether, // max invest
            300 ether, 
            9 ether, // softcap
            5,
            address(vToken)
        );
    }

    function testSlpxWithdrawFund() public {
        vToken.freeMoneyForEveryone(user, 15 ether);
        pool = ProjectPool(factory.getProjectPoolAddress(poolId));

        vm.prank(user);
        vToken.approve(address(pool), 10 ether);

        testUtil.whitelistUser(pool, user);
        uint256 amountToInvest = pool.getProjectMaxInvest() - pool.getUserDepositAmount(user);
        testUtil.userInvest(pool, user, amountToInvest);

        uint256 rightNow = block.timestamp;
        vm.warp(rightNow + 2 minutes);

        address projectOwner = pool.getProjectOwner();

        vm.startPrank(address(pool));
        uint256 withdrawAmount = pool.getWithdrawAmount();
        vToken.approve(address(mockSLPX), withdrawAmount);
        vm.stopPrank();

        vm.startPrank(projectOwner);
        uint256 poBal = projectOwner.balance;
        pool.slpxWithdrawFund();
        vm.stopPrank();

        vm.warp(rightNow);
        assertEq(projectOwner.balance, poBal + withdrawAmount);
    }

    receive() external payable {}
    fallback() external payable {}
}
