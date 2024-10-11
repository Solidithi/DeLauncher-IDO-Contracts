// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast(); // Start broadcasting transactions
        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
