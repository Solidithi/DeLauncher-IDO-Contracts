// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Launchpad {
    struct IDOProject {
        address tokenAddress;
        uint256 tokenSupply;
        uint256 tokenPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        bool isActive;
    }

    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;

    uint256 public whitelistStartTime;
    uint256 public whitelistEndTime;

    constructor(uint256 _whitelistStartTime, uint256 _whitelistEndTime) {
        require(
            _whitelistStartTime < _whitelistEndTime,
            "Invalid whitelist time range"
        );
        whitelistStartTime = _whitelistStartTime; //temp solution for whitelist
        whitelistEndTime = _whitelistEndTime;
    }

    mapping(uint256 => IDOProject) public projects;

    event Whitelisted(address indexed user, uint256 indexed projectId);
    event IDOCreated(
        uint256 projectId,
        address tokenAddress,
        uint256 tokenSupply,
        uint256 tokenPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 softCap
    );

    function signUpForWhitelist(uint256 _projectId) public {
        require(
            block.timestamp >= whitelistStartTime,
            "Whitelist registration not started yet"
        );
        require(
            block.timestamp <= whitelistEndTime,
            "Whitelist registration has ended"
        );
        require(
            !isWhitelisted(_projectId, msg.sender),
            "Already whitelisted for this project"
        );

        whitelistedAddresses[_projectId][msg.sender] = true;

        emit Whitelisted(msg.sender, _projectId);
    }

    function isWhitelisted(
        uint256 _projectId,
        address _address
    ) public view returns (bool) {
        return whitelistedAddresses[_projectId][_address];
    }
}
