// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProjectPool} from "../../../contracts/ProjectPool.sol"; 
import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {MockSLPX} from "../../../script/slpx.s.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract slpxBossTest is Test {
    MockVToken vToken;
    MockProjectToken projectToken;
    MockSLPX mockSLPX;
    ProjectPool pool;
    ProjectPoolFactory factory;
    ProjectPoolTestUtil testUtil;
    ProjectPool.ProjectDetail pr;
    address mockSlpxAddr;

    address payable bigBoss = payable(address(0x01)); 

    function setUp() public {
        vToken = new MockVToken();
        projectToken = new MockProjectToken(); 

        mockSLPX = new MockSLPX{value: 10 ether}(vToken);

        vm.deal(bigBoss, 5 ether); 
        mockSlpxAddr = address(mockSLPX); 

        testUtil = new ProjectPoolTestUtil();
        factory = new ProjectPoolFactory(mockSlpxAddr);

        pool = testUtil.createTestProjectPool(factory);
        pr = pool.getProjectDetail();

        console.log("Test setup complete");
    }

    function test_WithdrawWithRedeemAsset() public {
        uint256 customProjectId = factory.createProjectPool(
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

        address payable poolAddress = payable(factory.getProjectPoolAddress(customProjectId)); 
        ProjectPool customPool = ProjectPool(poolAddress);

        address investor = address(0x021);

        vToken.freeMoneyForEveryone(investor, customPool.getProjectMaxInvest());

        vm.prank(investor);
        vToken.approve(address(customPool), customPool.getProjectMaxInvest());

        testUtil.whitelistUser(customPool, investor);
        uint256 amountToInvest = customPool.getProjectMaxInvest() - customPool.getUserDepositAmount(investor);
        testUtil.userInvest(customPool, investor, amountToInvest);

        uint256 rightNow = block.timestamp;
        vm.warp(rightNow + 2 minutes);

        address projectOwner = customPool.getProjectOwner();
        uint256 poBalBefore = address(projectOwner).balance;

        console.log("vToken address:", address(vToken));
        console.log("customPool address:", address(customPool));
        console.log("Project owner address:", projectOwner);
        console.log("function address:", address(this));
        console.log("slpx address:", mockSlpxAddr);

        vToken.approve(mockSlpxAddr, customPool.getWithdrawAmount());

        vm.prank(projectOwner); 
        customPool.slpxWithdrawFund();

        uint256 poBalAfter = address(projectOwner).balance;
        assert(poBalAfter > poBalBefore); 

        vm.warp(rightNow); 
    }

}
