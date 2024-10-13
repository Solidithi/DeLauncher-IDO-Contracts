// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.24;

// import "forge-std/Test.sol";
// import {ProjectPool} from "../../../contracts/ProjectPool.sol"; // Adjust the path to your contract
// import {ProjectPoolFactory} from "../../../contracts/ProjectPoolFactory.sol";
// import {ProjectPoolTestUtil, MockVToken, MockProjectToken} from "../../../script/ProjectPoolTestUtil.s.sol";
// import {console} from "forge-std/console.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

// contract InvestProjectTest is Test {
//     // test props
//     ProjectPool pool;
//     ProjectPoolFactory factory;
//     ProjectPoolTestUtil testUtil;
// 	ProjectPool.ProjectDetail pr;
//     address mockSlpxAddr = address(0x01);

//     constructor() {
//         testUtil = new ProjectPoolTestUtil();
//         factory = new ProjectPoolFactory(mockSlpxAddr);
//     }

//     function setUp() public {
//         pool = testUtil.createTestProjectPool(factory);
// 		pr = pool.getProjectDetail();
//     }

//     function test_RevertIf_IDOHasEnded() external {
//         uint256 rightNow = block.timestamp;
//         uint256 afterProjectEnd = pr.endTime + 5 minutes;

//         // manipulate block timestamp
//         vm.warp(afterProjectEnd);

//         // assertion
//         vm.expectRevert(ProjectPool.ProjectIDOHasEnded.selector);
//         pool.joinWhitelist();

//         // reset timestamp
//         vm.warp(rightNow);
//     }

//     function test_RevertIf_IDOHasNotStarted() external {
//         uint256 rightNow = block.timestamp;

//         // manipulate block timestamp
//         uint256 fiveMinsLater = rightNow + 5 minutes;
//         vm.warp(fiveMinsLater);
//         vm.warp(rightNow);

//         // assertion
//         vm.expectRevert(ProjectPool.ProjectIDOHasNotStarted.selector);
//         pool.joinWhitelist();

//         // reset timestamp
//         vm.warp(rightNow);
//     }

//     function test_RevertIf_ReserveAmountNotReached() external {
//         // assertion
//         vm.expectRevert(ProjectPool.NotEnoughERC20Allowance.selector);
//         pool.joinWhitelist();
//     }

//     function test_RevertIf_ReserveAmountNotReached2() external {
//         address vAsset = pool.getAcceptedVAsset();
//         uint256 reserveAmount = pool.getReserveInvestment();
//         IERC20(vAsset).approve(address(pool), reserveAmount - 1);

//         // assertion
//         vm.expectRevert(ProjectPool.NotEnoughERC20Allowance.selector);
//         pool.joinWhitelist();
//     }

//     function test_RevertIf_UserNotWhitelisted() external {
//         address vAsset = pool.getAcceptedVAsset();
//         uint256 reserveAmount = pool.getReserveInvestment();
//         MockVToken(vAsset).freeMoneyForEveryone(address(this), reserveAmount);
//         IERC20(vAsset).approve(address(pool), reserveAmount);

//         // assertion
//         vm.expectRevert(ProjectPool.UserNotWhitelisted.selector);
//         uint256 moreThanMinInvest = pool.getProjectMinInvest() + 1;
//         pool.investProject(moreThanMinInvest);
//     }
// }
