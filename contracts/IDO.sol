// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract IDO {
    struct Project {
        address tokenAddress;
        uint256 tokenSupply;
        uint256 tokenPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        bool isActive;
        WhiteList whitelist;
    }

    struct WhiteList {
        uint256 startTime;
        uint256 endTime;
    }

    address public owner;
    mapping(address => uint256) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;

    uint256 public whitelistStartTime;
    uint256 public whitelistEndTime;

    event Whitelisted(address indexed user, uint256 indexed projectId);
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed tokenAddress
    );

    constructor(address _owner) {
        owner = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function addProject(
        uint256 _projectId,
        Project memory _project
    ) public onlyOwner {
        projects[_projectId] = _project;
        emit ProjectCreated(_projectId, _project.tokenAddress);
    }

    function createWhiteList(
        uint256 _projectId,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        require(_startTime < _endTime, "invalid whitelist period");

        projects[_projectId].whitelist.startTime = _startTime;
        projects[_projectId].whitelist.endTime = _endTime;
    }

    function signUpForWhitelist(uint256 _projectId) public {
        require(
            block.timestamp >= projects[_projectId].whitelist.startTime,
            "Whitelist registration not started yet"
        );
        require(
            block.timestamp <= projects[_projectId].whitelist.endTime,
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
