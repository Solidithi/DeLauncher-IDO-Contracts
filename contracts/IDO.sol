// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IDO is Ownable {
    struct Project {
        uint256 projectId;
        address projectOwner;
        address tokenAddress;
        // uint256 tokenForSale; // Not needed anymore 🔥
        uint256 pricePerToken;
        uint256 startTime;
        uint256 endTime;
        uint256 raisedAmount;
        // The maximum monetary worth of fund that the project can raise
        uint256 hardCapAmount;
        // The minimum monetary worth of fund that the project must raise
        uint256 softCapAmount;
        // The minimum monetary value of an individual's investment
        uint256 minInvest;
        // The maximum monetary value of an individual's investment
        uint256 maxInvest;
        // vAssets that project accepts
        address[] acceptedVAssets;
        // reward rate
        uint256 rewardRate; // use RATE_DECIMALS
    }

    /**
     * @dev use 4 DECIMALS for numbers related to rate
     * example: 1000 is equivalent to 1 (100 %)
     * example: 10 is equivalent to 0.001 (1 %)
     */
    uint256 public constant RATE_DECIMALS = 4;

    // Address of Bifrost SLPX contract
    address public slpxAddress;

    //
    uint256 public IDOFeeRate = 50; // 0.005

    // address public owner;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;
    // mapping(uint256 => address) public projectOwners; // 🔥 This is not needed

    /**
     *
     * @notice This map exists for the purpose of quickly checking
     * whether a project supports particular vAsset
     *
     * @dev This mapping could be viewed as:
     * maping(vAssetAddress => mapping(projectId => true/false))
     */
    mapping(uint256 => mapping(address => bool)) acceptedVAssets;

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

    constructor(address _slpxAddress) Ownable(msg.sender) {
        // Already inherits OpenZeppelin's Ownable contract 🔥
        // owner = msg.sender;
        slpxAddress = _slpxAddress;
    }

    // 🔥 Already inherits this func from OpenZeppelin's Ownable contract
    // modifier onlyOwner() {
    //     require(msg.sender == owner, "Caller is not the owner");
    //     _;
    // }

    modifier onlyProjectOwner(uint256 _projectId) {
        require(
            msg.sender == projects[_projectId].projectOwner,
            "Caller is not the project owner"
        );
        _;
    }

    modifier validProject(uint256 _projectId) {
        if (_projectId > currentProjectID || _projectId <= 0) {
            revert invalidProjectID();
        }

        // 🔥 No need to check 'projects[_projectId].tokenAddress != address(0)' here
        // if (projects[_projectId].tokenAddress == address(0)) {
        // 	revert ZeroAddress();
        // }
        _;
    }

    modifier notZeroAddress(address a) {
        if (a == address(0)) {
            revert ZeroAddress();
        }
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
    error ZeroAddress();
    error VAssetNotAcceptedByProject();

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
        uint256 _maxInvest,
        uint256 _hardCapAmount,
        uint256 _softCapAmount,
        uint256 _rewardRate,
        address[] memory _acceptedVAssets
    ) public notZeroAddress(_tokenAddress) {
        if (_tokenForSale <= 0) {
            revert tokenForSaleMustBePositive();
        }

        Project memory newProject = Project({
            projectId: currentProjectID,
            projectOwner: msg.sender,
            tokenAddress: _tokenAddress,
            // tokenForSale: _tokenForSale,
            pricePerToken: _pricePerToken,
            startTime: _startTime,
            endTime: _endTime,
            raisedAmount: 0,
            minInvest: _minInvest,
            maxInvest: _maxInvest,
            hardCapAmount: _hardCapAmount,
            softCapAmount: _softCapAmount,
            acceptedVAssets: _acceptedVAssets,
            rewardRate: _rewardRate
        });

        for (uint256 i = 0; i < _acceptedVAssets.length; i++) {
            address vAsset = _acceptedVAssets[i];
            acceptedVAssets[currentProjectID][vAsset] = true;
        }

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
    // function investProject(
    //     uint256 _projectId,
    // )
    //     public
    //     payable
    //     validProject(_projectId)
    //     IDOStillAvailable(_projectId)
    //     needToBeWhitelisted(msg.sender, _projectId)
    // {
    //     projects[_projectId].raisedAmount += msg.value;
    //     balances[msg.sender][_projectId] += msg.value;

    //     emit Invested(msg.sender, _projectId, msg.value);
    // }

    function investProject(
        uint256 projectId,
        address vAssetAddress,
        uint256 amount
    )
        public
        validProject(projectId)
        IDOStillAvailable(projectId)
        needToBeWhitelisted(msg.sender, projectId)
    {
        /**
         * @dev cache msg.sender and address(this) once
         * to limit reading from state too many
         */
        address investor = msg.sender;
        address contractAddr = address(this);

        // Check if vAsset is accepted by project
        bool vAssetAccepted = isVAssetAcceptedByProject(
            vAssetAddress,
            projectId
        );
        if (!vAssetAccepted) {
            revert VAssetNotAcceptedByProject();
        }

        // Check vAsset allowance
        require(
            IERC20(vAssetAddress).allowance(investor, address(this)) >= amount,
            "user not sufficiently approve vAsset for IDO"
        );

        IERC20(vAssetAddress).transferFrom(investor, contractAddr, amount);

        // Check monetary constraints:
        // call XCM Oracle contract to know the amount of token (X) equivalent to user's vToken amount
        // swap
        // gets the price of X in USDT or USD using data from an Oracle (like Band Protocol)
        // // The price of X stands for how much the user's investment is worth in USD
        // // Get project's fund raised amount (FRA)
        // // check if X + FRA <= project's hardcap
        // // check if X >= minInvest && X <= maxInvest

        // Update states
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

    function getProjectHardCapAmount(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].hardCapAmount;
    }

    function getProjectSoftCapAmount(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].softCapAmount;
    }

    function isProjectActive(
        uint256 _projectId
    ) public view validProject(_projectId) returns (bool) {
        return (block.timestamp > projects[_projectId].endTime);
    }

    function isVAssetAcceptedByProject(
        address vAssetAddress,
        uint256 projectId
    ) public view returns (bool) {
        return acceptedVAssets[projectId][vAssetAddress];
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

    /**
     * 🔥 Since we switched to OpenZeppelin's Ownable contract,
     * the owner of the contract could be changed,
     * so the owner can be different from deployer
     */
    // function getDeployer() public view returns (address) {
    //     return owner;
    // }

    function setSlpxAddress(address _slpxAddress) public onlyOwner {
        slpxAddress = _slpxAddress;
    }

    function setIDOFeeRate(uint256 _IDOfeeRate) public onlyOwner {
        IDOFeeRate = _IDOfeeRate;
    }
}
