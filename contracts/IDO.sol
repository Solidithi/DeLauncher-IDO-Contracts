// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract IDO {
    struct Project {
        uint256 projectId;
        address projectOwner;
        address tokenAddress;
        uint256 tokenForSale;
        uint256 pricePerToken;
        uint256 startTime;
        uint256 endTime;
        uint256 raisedAmount;
        uint256 minInvest;
        uint256 maxInvest;
    }

    address public owner;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;
    mapping(uint256 => address) public projectOwners;

    uint256 currentProjectID = 1;

    event Whitelisted(address indexed user, uint256 indexed projectId);
    event ProjectCreated(
        address indexed projectOwner,
        address indexed tokenAddress,
        uint256 tokenForSale,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime
    );
    event Invested(
        address indexed user,
        uint256 indexed projectId,
        uint256 indexed amount
    );
    event ProjectWithdrawn(address indexed user, uint256 indexed projectId);

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

    modifier validProject(uint256 _projectId) {
        if (_projectId > currentProjectID || _projectId <= 0) {
            revert invalidProjectID();
        }
        require(
            projects[_projectId].tokenAddress != address(0),
            "Invalid token address"
        );
        _;
    }

    modifier IDOStillAvailable(uint256 _projectId) {
        require(
            block.timestamp < projects[_projectId].endTime,
            "Project IDO has ended"
        );
        _;
    }

    modifier needToBeWhitelisted(address _investor, uint256 _projectId) {
        require(
            whitelistedAddresses[_projectId][_investor],
            "Investor is not whitelisted"
        );
        _;
    }

    modifier notWhitelisted(address _investor, uint256 _projectId) {
        require(
            !whitelistedAddresses[_projectId][_investor],
            "Investor is already whitelisted"
        );
        _;
    }

    /**
     * @dev contract errors
     */
    error tokenPriceMustBePositive();
    error tokenForSaleMustBePositive();
    error invalidProjectID();

    /**
     * @dev contract deployer will put up a new project
     * @param _startTime project launchpad start time
     * @param _endTime project launcchpad end time
     */
    function addProject(
        address _tokenAddress,
        uint256 _tokenForSale,
        uint256 _pricePerToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minInvest,
        uint256 _maxInvest
    ) public {
        require(_tokenAddress != address(0), "Token address need to exist");
        if (_tokenForSale <= 0) {
            revert tokenForSaleMustBePositive();
        }

        Project memory newProject = Project({
            projectId: currentProjectID,
            projectOwner: msg.sender,
            tokenAddress: _tokenAddress,
            tokenForSale: _tokenForSale,
            pricePerToken: _pricePerToken,
            startTime: _startTime,
            endTime: _endTime,
            raisedAmount: 0,
            minInvest: _minInvest,
            maxInvest: _maxInvest
        });

        projects[currentProjectID] = newProject;

        emit ProjectCreated(
            msg.sender,
            _tokenAddress,
            _tokenForSale,
            _pricePerToken,
            _startTime,
            _endTime
        );

        currentProjectID++;
    }

    function withdraw(uint256 _projectId) public onlyProjectOwner(_projectId) {
        require(
            block.timestamp > projects[_projectId].endTime,
            "Project is still active"
        );
        uint256 projectRaisedAmount = projects[_projectId].raisedAmount;
        payable(msg.sender).transfer(projectRaisedAmount);
        projects[_projectId].raisedAmount = 0;
        emit ProjectWithdrawn(msg.sender, _projectId);
    }

    /**
     * @dev temp solution before we intergrated Bifrost
     */
    function investProject(
        uint256 _projectId
    )
        public
        payable
        validProject(_projectId)
        IDOStillAvailable(_projectId)
        needToBeWhitelisted(msg.sender, _projectId)
    {
        projects[_projectId].raisedAmount += msg.value;
        balances[msg.sender][_projectId] += msg.value;

        emit Invested(msg.sender, _projectId, msg.value);
    }

    function joinWhitelist(
        uint256 _projectId
    )
        public
        payable
        validProject(_projectId)
        IDOStillAvailable(_projectId)
        notWhitelisted(msg.sender, _projectId)
    {
        require(
            msg.value >= getReserveInvestment(_projectId),
            "Minimum reserve amount not reach"
        );
        require(
            msg.value <= projects[_projectId].maxInvest,
            "Reserve amount must lower than max investment cap"
        );
        projects[_projectId].raisedAmount += msg.value;
        balances[msg.sender][_projectId] += msg.value;

        whitelistedAddresses[_projectId][msg.sender] = true;
        emit Whitelisted(msg.sender, _projectId);
    }

    /**
     * @dev view functions
     * @param _projectId the project id number
     * @param _address the user adr that check for whitelisted or not on the corresponding project
     */
    function isWhitelisted(
        uint256 _projectId,
        address _address
    ) public view validProject(_projectId) returns (bool) {
        return whitelistedAddresses[_projectId][_address];
    }

    function getProjectFullDetails(
        uint256 _projectId
    ) public view validProject(_projectId) returns (Project memory) {
        return projects[_projectId];
    }

    function getProjecttokenForSale(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].tokenForSale;
    }

    function isProjectActive(
        uint256 _projectId
    ) public view validProject(_projectId) returns (bool) {
        return (block.timestamp > projects[_projectId].endTime);
    }

    function getTimeLeftUntilProjecctEnd(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].endTime - block.timestamp;
    }

    function getCurrentProjectId() public view returns (uint256) {
        return currentProjectID;
    }

    function getInvestedAmount(
        address _userAdr,
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        uint256 investedAmount = balances[_userAdr][_projectId];
        require(investedAmount > 0, "User  has not invested in this project");
        return investedAmount;
    }

    function getReserveInvestment(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].minInvest / 2;
    }

    function getDeployer() public view returns (address) {
        return owner;
    }
}
