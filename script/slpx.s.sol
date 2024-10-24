// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockVToken} from "./ProjectPoolTestUtil.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract MockSLPX {
    MockVToken public vToken;  

    constructor(MockVToken _vToken) payable {
        vToken = _vToken;

        require(msg.value > 0, "Must send some native tokens to contract");

        vToken.freeMoneyForEveryone(address(this), 100000 * 10**18); 
    }

    function mintVNativeAsset(address receiver, string memory remark) external payable {
        require(msg.value > 0, "No native token sent");

        bool success = vToken.transfer(receiver, msg.value);

        require(success, "Mint Failed");

        console.log("vToken minted to address:", receiver, remark);
    }

    function redeemAsset(address vAssetAddress, uint256 amount, address payable receiver) external {
   
        require(vAssetAddress == address(vToken), "Invalid vAsset address");
        require(vToken.balanceOf(msg.sender) >= amount, "Insufficient vToken balance");
        require(address(this).balance >= amount, "Contract does not have enough native tokens");
        // require(!isContract(receiver), "Receiver cannot be a contract without payable fallback");

        bool success = vToken.transferFrom(msg.sender, address(this), amount);
        console.log("Transfer from user to contract success:", success);
        require(success, "Token transfer failed");

        (bool sent, ) = receiver.call{value: amount}("");
        require(sent, "Failed to send native tokens");
    }
}
