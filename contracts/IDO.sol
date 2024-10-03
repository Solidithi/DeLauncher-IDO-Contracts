// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract IDO {
    struct Project {
        address projectOwner;
        address tokenAddress;
        uint256 tokenSupply;
        uint256 fund;
        uint256 pricePerToken;
        uint256 startTime;
        uint256 endTime;
        uint256 whiteListCap;
        uint256 raisedAmount;
    }

    address public owner;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => address) public projectOwners;

    uint256 currentProjectID = 0;

    event Whitelisted(address indexed user, uint256 indexed projectId);
    event ProjectCreated(
        address indexed tokenAddress,
        uint256 tokenSupply,
        uint256 fund,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime
    );
    event Invested(
        address indexed user,
        uint256 indexed projectId,
        uint256 indexed amount
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyProjectOwner(uint256 _projectId) {
        require(
            msg.sender == projectOwners[_projectId],
            "Caller is not the project owner"
        );
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
        address _tokenAddress,
        uint256 _tokenSupply,
        uint256 _fund,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _whiteListCap
    ) public {
        require(_tokenAddress != address(0), "Token address need to exist");
        if (_tokenSupply <= 0) {
            revert tokenSupplyMustBePositive();
        }
        if (_fund <= 0) {
            revert fundMustBePositive();
        }

        Project memory newProject = Project({
            projectOwner: msg.sender,
            tokenAddress: _tokenAddress,
            tokenSupply: _tokenSupply,
            fund: _fund,
            pricePerToken: 0,
            startTime: _startTime,
            endTime: _endTime,
            whiteListCap: _whiteListCap,
            raisedAmount: 0
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
     * @dev temp solution before we intergrated Bifrost
     */
    function investProject(uint256 _projectId) public payable {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        require(
            projects[_projectId].tokenAddress != address(0),
            "Project does not exist"
        );
        require(
            block.timestamp < projects[_projectId].endTime,
            "Project has ended"
        );

        projects[_projectId].raisedAmount += msg.value;
        balances[msg.sender][_projectId] += msg.value;

        emit Invested(msg.sender, _projectId, msg.value);
    }

    /**
     * @dev public function, everyone can sign up for whitelist
     * @dev temp solution until intergrating Bifrost
     * @param _projectId the project id
     */
    function signUpForWhitelist(uint256 _projectId) public {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        require(
            projects[_projectId].tokenAddress != address(0),
            "Project does not exist"
        );
        require(
            !isWhitelisted(_projectId, msg.sender),
            "Already whitelisted for this project"
        );

        uint256 investedAmount = getInvestedAmount(msg.sender, _projectId);
        require(
            investedAmount >= projects[_projectId].whiteListCap,
            "Insufficient investment"
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

    function getInvestedAmount(
        address _userAdr,
        uint256 _projectId
    ) public view returns (uint256) {
        if (_projectId > currentProjectID || _projectId < 0) {
            revert invalidProjectID();
        }
        uint256 investedAmount = balances[_userAdr][_projectId];
        require(investedAmount > 0, "User  has not invested in this project");
        return investedAmount;
    }
}
