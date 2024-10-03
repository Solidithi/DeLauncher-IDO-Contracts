// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract IDO {
    struct Project {
        IERC20 tokenAddress;
        uint256 tokenSupply;
        uint256 fund;
        uint256 pricePerToken;
        uint256 startTime;
        uint256 endTime;
        WhiteList whitelist;
    }

    struct WhiteList {
        uint256 WLStartTime;
        uint256 WLEndTime;
    }

    address public owner;
    mapping(address => uint256) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;

    uint256 currentProjectID = 0;

    event Whitelisted(address indexed user, uint256 indexed projectId);
    event ProjectCreated(
        IERC20 indexed tokenAddress,
        uint256 tokenSupply,
        uint256 fund,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }
    /**
     * @dev contract errors
     */
    error tokenPriceMustBePositive();
    error tokenSupplyMustBePositive();
    error fundMustBePositive();
    error invalidProjectID();

    /**
     * @dev contract deployer will put up a new project
     * @param _startTime project launchpad start time
     * @param _endTime project launcchpad end time
     */
    function addProject(
        IERC20 _tokenAddress,
        uint256 _tokenSupply,
        uint256 _fund,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        if (_tokenSupply <= 0) {
            revert tokenSupplyMustBePositive();
        }
        if (_fund <= 0) {
            revert fundMustBePositive();
        }

        Project memory newProject = Project({
            tokenAddress: _tokenAddress,
            tokenSupply: _tokenSupply,
            fund: _fund,
            pricePerToken: 0,
            startTime: _startTime,
            endTime: _endTime,
            whitelist: WhiteList({WLStartTime: 0, WLEndTime: 0})
        });
        projects[currentProjectID] = newProject;

        uint256 tokenPrice = getProjectTokenPrice(currentProjectID);
        if (tokenPrice <= 0) {
            revert tokenPriceMustBePositive();
        }

        newProject.pricePerToken = tokenPrice;

        emit ProjectCreated(
            _tokenAddress,
            _tokenSupply,
            _fund,
            tokenPrice,
            _startTime,
            _endTime
        );
        currentProjectID++;
    }

    /**
     * @dev contract deployer can put a whitelist event for a specific project
     * @dev temp solution
     * @dev #todo discuss later
     * @param _startTime whitelist end time
     * @param _endTime whitelist start time
     */
    function createWhiteList(
        uint256 _projectId,
        uint256 _startTime,
        uint256 _endTime
    ) public onlyOwner {
        require(_startTime < _endTime, "invalid whitelist period");

        projects[_projectId].whitelist.WLStartTime = _startTime;
        projects[_projectId].whitelist.WLEndTime = _endTime;
    }

    /**
     * @dev public function, everyone can sign up for whitelist
     * @param _projectId the project id
     */
    function signUpForWhitelist(uint256 _projectId) public {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        require(
            projects[_projectId].tokenAddress != IERC20(address(0)),
            "Project does not exist"
        );
        require(
            block.timestamp >= projects[_projectId].whitelist.WLStartTime,
            "Whitelist registration not started yet"
        );
        require(
            block.timestamp <= projects[_projectId].whitelist.WLEndTime,
            "Whitelist registration has ended"
        );
        require(
            !isWhitelisted(_projectId, msg.sender),
            "Already whitelisted for this project"
        );

        whitelistedAddresses[_projectId][msg.sender] = true;

        emit Whitelisted(msg.sender, _projectId);
    }

    /**
     * @dev this function calculate listing price of project token
     * @param _projectId the project id number
     */
    function getProjectTokenPrice(
        uint256 _projectId
    ) public view returns (uint256) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return projects[_projectId].fund / projects[_projectId].tokenSupply;
    }

    /**
     * @dev view functions
     * @param _projectId the project id number
     * @param _address the user adr that check for whitelisted or not on the corresponding project
     */
    function isWhitelisted(
        uint256 _projectId,
        address _address
    ) public view returns (bool) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return whitelistedAddresses[_projectId][_address];
    }

    function getProjectFullDetails(
        uint256 _projectId
    ) public view returns (Project memory) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return projects[_projectId];
    }

    function getProjectTokenSupply(
        uint256 _projectId
    ) public view returns (uint256) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return projects[_projectId].tokenSupply;
    }

    function getProjectFund(uint256 _projectId) public view returns (uint256) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return projects[_projectId].fund;
    }

    function isProjectActive(uint256 _projectId) public view returns (bool) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }

        return (block.timestamp > projects[_projectId].endTime);
    }

    function getTimeLeftUntilProjecctEnd(
        uint256 _projectId
    ) public view returns (uint256) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        return projects[_projectId].endTime - block.timestamp;
    }

    function getCurrentProjectId() public view returns (uint256) {
        return currentProjectID;
    }
}
