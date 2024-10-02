// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console2, stdError} from "forge-std/Test.sol";
import {Launchpad} from "../contracts/LaunchPad.sol";

contract LaunchpadTest is Test {
    Launchpad public launchpad;
    address user1 = makeAddr("User1");
    address user2 = makeAddr("User2");

    event TestResult(string testName, bool success);

    constructor() {
        launchpad = new Launchpad(block.timestamp, block.timestamp + 1 weeks);
    }

    function testSignUpForWhitelist() public {
        vm.startPrank(user1);
        launchpad.signUpForWhitelist(1);
        bool _isWhiteListed = launchpad.isWhitelisted(1, user1);
        require(_isWhiteListed, "User1 should be whitelisted");
        emit TestResult("testSignUpForWhitelist", true);
        vm.stopPrank();
    }
}
