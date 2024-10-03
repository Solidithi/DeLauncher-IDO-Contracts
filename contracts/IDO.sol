// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract IDO {
    struct Project {
        address tokenAddress;
        uint256 tokenSupply;
        uint256 tokenPrice;
        uint256 startTime;
        uint256 endTime;
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
        address indexed tokenAddress,
        uint256 tokenSupply,
        uint256 tokenPrice,
        uint256 start,
        uint256 end
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    function addProject(
        uint256 _projectId,
        address _tokenAddress,
        uint256 _tokenSupply,
        uint256 _tokenPrice,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        Project memory newProject = Project({
            tokenAddress: _tokenAddress,
            tokenSupply: _tokenSupply,
            tokenPrice: _tokenPrice,
            startTime: _startTime,
            endTime: _endTime,
            whitelist: WhiteList({startTime: 0, endTime: 0})
        });
        projects[_projectId] = newProject;

        emit ProjectCreated(
            _projectId,
            _tokenAddress,
            _tokenSupply,
            _tokenPrice,
            _startTime,
            _endTime
        );
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
        require(projects[_projectId].startTime != 0, "Project does not exist");
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
