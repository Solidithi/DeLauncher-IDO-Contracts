// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface IIDO {
    address public owner;
    mapping(address => uint256) public balances;

    function withDraw(address projectAddress) public returns (bool);
}
