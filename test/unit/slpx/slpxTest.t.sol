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
    MockSLPX mockSLPX;
    ProjectPool pool;
    ProjectPoolFactory factory;
    ProjectPoolTestUtil testUtil;
    ProjectPool.ProjectDetail pr;
    address mockSlpxAddr;

    address payable bigBoss = payable(address(0x01)); // Payable address for bigBoss
    MockProjectToken projectToken; // Declaring projectToken

    function setUp() public {
        vToken = new MockVToken();
        projectToken = new MockProjectToken(); // Initializing projectToken

        mockSLPX = new MockSLPX{value: 10 ether}(vToken);

        vm.deal(bigBoss, 5 ether); // Fund bigBoss with 5 ether
        mockSlpxAddr = address(mockSLPX); // Save MockSLPX address

        testUtil = new ProjectPoolTestUtil();
        factory = new ProjectPoolFactory(mockSlpxAddr);

        pool = testUtil.createTestProjectPool(factory);
        pr = pool.getProjectDetail();

        console.log("Test setup complete");
    }
    function test_WithdrawWithRedeemAsset() public {
    // Create a new project pool with bigBoss as the owner
    uint256 customProjectId = factory.createProjectPool(
        address(projectToken), // Using MockProjectToken
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

    // Fetching the created pool's address
    address payable poolAddress = payable(factory.getProjectPoolAddress(customProjectId)); // Ensure pool address is payable
    ProjectPool customPool = ProjectPool(poolAddress);

    address investor = address(0x021);

    // Fund the investor and set allowances
    vToken.freeMoneyForEveryone(investor, customPool.getProjectMaxInvest());

    // Prank as investor to approve spending and invest
    vm.prank(investor);
    vToken.approve(address(customPool), customPool.getProjectMaxInvest());

    // Whitelist the investor and have them invest the amount needed
    testUtil.whitelistUser(customPool, investor);
    uint256 amountToInvest = customPool.getProjectMaxInvest() - customPool.getUserDepositAmount(investor);
    testUtil.userInvest(customPool, investor, amountToInvest);

    // Fast forward time to simulate project ending
    uint256 rightNow = block.timestamp;
    vm.warp(rightNow + 2 minutes); // Simulate after the project duration

    // Capture bigBoss's initial balance before withdrawal
    address projectOwner = customPool.getProjectOwner();
    uint256 poBal = address(projectOwner).balance;

    // Debugging the allowance before attempting withdrawal
    uint256 withdrawAmount = customPool.getWithdrawAmount();
    console.log("Withdraw Amount: ", withdrawAmount);
    console.log("Allowance Before: ", vToken.allowance(projectOwner, address(customPool)));

    // Prank as the project owner to approve the allowance
    vm.prank(projectOwner); 
    uint256 amountToWithdraw = customPool.getWithdrawAmount();
    vToken.approve(mockSlpxAddr, amountToWithdraw);
    // Check allowance again after approval
    console.log("Allowance After: ", vToken.allowance(projectOwner, address(customPool)));

    // Now call the withdraw function
    customPool.slpxWithdrawFund(); // Assuming slpxWithdrawFund sends Ether back

    // Assert that the balance has changed
    assert(poBal != address(projectOwner).balance);

    // Reset the timestamp
    vm.warp(rightNow);
}

}
