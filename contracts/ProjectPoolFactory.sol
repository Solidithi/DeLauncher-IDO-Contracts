// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProjectPool} from "./ProjectPool.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

contract ProjectPoolFactory is Ownable {
    // projectId => Project pool address
    mapping(uint256 => address) projectPools;
    // project pool address => is valid/not valid
    mapping(address => bool) poolIsValid;
    uint256 public currentProjectId = 1;
    address public slpxAddress;

    error InvalidProjectId();

    event ProjectPoolCreated(
        address indexed projectOwner,
        address indexed tokenAddress,
        uint256 projectId,
        uint256 startTime,
        uint256 endTime
    );

    constructor(address _slpxAddress) Ownable(_msgSender()) {
        slpxAddress = _slpxAddress;
    }

    /**
     * @return project ID (uint256)
     */
    function createProjectPool(
        address tokenAddress,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime,
        uint256 minInvest,
        uint256 maxInvest,
        uint256 hardCapAmount,
        uint256 softCapAmount,
        uint256 rewardRate,
        address acceptedVAsset
    ) public returns (uint256) {
        // create project
        address projectOwner = _msgSender();
        uint256 newProjectId = currentProjectId;
        ProjectPool newProjectPool = new ProjectPool(
            projectOwner,
            tokenAddress,
            pricePerToken,
            startTime,
            endTime,
            minInvest,
            maxInvest,
            hardCapAmount,
            softCapAmount,
            rewardRate,
            acceptedVAsset,
            slpxAddress
        );

        // update states
        projectPools[newProjectId] = address(newProjectPool);
        poolIsValid[address(newProjectPool)] = true;
        currentProjectId++;

        emit ProjectPoolCreated(
            _msgSender(),
            tokenAddress,
            newProjectId,
            startTime,
            endTime
        );

        return newProjectId;
    }

    function getCurrentProjectId() public view returns (uint256) {
        return currentProjectId;
    }

    function getProjectPoolAddress(
        uint256 projectId
    ) public view validProjectId(projectId) returns (address) {
        return projectPools[projectId];
    }

    function checkPoolIsValid(address poolAddress) public view returns (bool) {
        return poolIsValid[poolAddress];
    }

    function setSlpxAddress(address _slpxAddress) public onlyOwner {
        slpxAddress = _slpxAddress;
    }

    modifier validProjectId(uint256 projectId) {
        if (projectId >= currentProjectId || projectId <= 0) {
            revert InvalidProjectId();
        }
        _;
    }
}
