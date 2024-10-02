// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../contracts/LaunchPad.sol";
import {Script, console2} from "forge-std/Script.sol";

contract DeployLaunchpad is Script {
    Launchpad public launchpad;

    event LaunchpadDeployed(address launchpadAddress);

    function deployLaunchpad(
        uint256 _whitelistStartTime,
        uint256 _whitelistEndTime
    ) public {
        vm.startBroadcast();

        require(
            _whitelistStartTime < _whitelistEndTime,
            "Invalid whitelist time range"
        );

        launchpad = new Launchpad(_whitelistStartTime, _whitelistEndTime);
        emit LaunchpadDeployed(address(launchpad));

        vm.stopBroadcast();
    }
}
