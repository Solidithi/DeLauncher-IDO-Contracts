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

    function test_Correct_WithdrawAmount() external {
        ProjectPool somePool = testUtil.createTestProjectPool(factory);
        address vAsset = somePool.getAcceptedVAsset();
        MockVToken(vAsset).freeMoneyforEveryone(
            address(somePool),
            10000000000 * 10 ** vAsset.decimals()
        );
        
        factory


    }
}
