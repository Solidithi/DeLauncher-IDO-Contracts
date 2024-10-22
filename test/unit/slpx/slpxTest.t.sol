// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MockVToken} from "../../../script/ProjectPoolTestUtil.s.sol";
import {MockSLPX} from "../../../script/slpx.s.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract MockSLPXTest is Test {
    MockVToken vToken;
    MockSLPX mockSLPX;

    address user1 = address(0x01); 

    function setUp() public {
        vToken = new MockVToken();

        mockSLPX = new MockSLPX{value: 10 ether}(vToken);

        vm.deal(user1, 5 ether);

        console.log("Test setup complete");
    }

    function testMintVNativeAsset() public {
        vm.startPrank(user1); 
        assertEq(vToken.balanceOf(user1), 0);
        mockSLPX.mintVNativeAsset{value: 1 ether}(user1, "Mint vTokens");
        uint256 user1VTokenBalance = vToken.balanceOf(user1);
        assertEq(user1VTokenBalance, 1 ether);
        vm.stopPrank();

        console.log("Mint vNativeAsset successful");
    }

    function testRedeemAssetUsingCall() public {
        vm.startPrank(user1);

        uint256 contractBalanceBeforeMint = address(mockSLPX).balance;
        mockSLPX.mintVNativeAsset{value: 2 ether}(user1, "Mint vTokens");

        uint256 userVTokenBalance = vToken.balanceOf(user1);
        console.log(userVTokenBalance);

        assertEq(address(mockSLPX).balance, contractBalanceBeforeMint + 2 ether); 

        vToken.approve(address(mockSLPX), 1 ether);
        uint256 userBalanceBefore = user1.balance; 
        uint256 contractBalanceBeforeRedeem = address(mockSLPX).balance; 
        mockSLPX.redeemAsset(address(vToken), 1 ether, payable(user1));

        assertEq(user1.balance, userBalanceBefore + 1 ether); 

        assertEq(address(mockSLPX).balance, contractBalanceBeforeRedeem - 1 ether);

        vm.stopPrank();
    }
}
