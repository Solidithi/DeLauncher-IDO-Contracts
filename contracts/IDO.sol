// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract IDO {
    address public owner;
    mapping(address => uint256) public balances;

    constructor(address _owner) {
        owner = _owner;
    }
}
