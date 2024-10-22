// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockVToken} from "./ProjectPoolTestUtil.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract MockSLPX {
    MockVToken public vToken;  

    constructor(MockVToken _vToken) payable {
        vToken = new MockVToken;

        require(msg.value > 0, "Must send some native tokens to contract");

        vToken.freeMoneyForEveryone(address(this), 100000 * 10**18); 

        console.log("Contract initialized with vToken and native token reserve");
    }

    function mintVNativeAsset(address receiver, string memory remark) external payable {
        require(msg.value > 0, "No native token sent");

        bool success = IERC20(vToken.address).transfer(
            receiver,
            msg.value
        );

        require(success, "Mint Failed")

        console.log("Minted vAsset for", receiver, "Amount:", msg.value, "Remark:", remark);
    }

    function redeemAsset(address vAssetAddress, uint256 amount, address payable receiver) external {
        require(vToken.balanceOf(msg.sender) >= amount, "Insufficient vToken balance");

        bool success = vToken.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");

        require(address(this).balance >= amount, "Contract does not have enough native tokens");

        receiver.transfer(amount);

        console.log("Redeemed vAsset for", receiver, "Amount:", amount);
    }
}
