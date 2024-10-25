// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/ProjectPoolFactory.sol";

contract MyScript is Script {
    function run() external {
        vm.startBroadcast(); // Start broadcasting transactions
        address Bifrost_slpx = 0xc6bf0C5C78686f1D0E2E54b97D6de6e2cEFAe9fD;
        ProjectPoolFactory factory = new ProjectPoolFactory(Bifrost_slpx);
        console.log("IDO Factory deploy at: ", address(factory));
        vm.stopBroadcast(); // Stop broadcasting transactions
    }
}
