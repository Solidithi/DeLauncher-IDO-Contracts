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
        // The maximum amount of vAsset the project can raise
        uint256 hardCapAmount;
        // The minimum amount of vAsset the project must raise
        uint256 softCapAmount;
        // The minimum vAsset amount of an individual's investment
        uint256 minInvest;
        // The maximum vAsset amount of an individual's investment
        uint256 maxInvest;
        // vAsset that the project accepts
        address acceptedVAsset;
        // the proportion of raised fund that is reserved for rewarding investors
        uint256 rewardRate; // use RATE_DECIMALS
    }

	////////////////////////////////////////////////////
	//////////////// CONTRACT STATES //////////////////
	//////////////////////////////////////////////////
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

    uint256 currentProjectId = 1;

    // address public owner;
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(uint256 => mapping(address => bool)) private whitelistedAddresses;
    mapping(uint256 => Project) public projects;
    // mapping(uint256 => address) public projectOwners; // 🔥 This is not needed


	////////////////////////////////////////////////////
	//////////////// CONTRACT EVENTS //////////////////
	//////////////////////////////////////////////////
    event Whitelisted(address indexed user, uint256 indexed projectId);
    event ProjectCreated(
        address indexed projectOwner,
        address indexed tokenAddress,
		uint256 projectId,
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

	////////////////////////////////////////////////////
	/////////////// CONTRACT MODIFIERS ////////////////
	//////////////////////////////////////////////////
    modifier onlyProjectOwner(uint256 _projectId) {
        require(
            _msgSender() == projects[_projectId].projectOwner,
            "Caller is not the project owner"
        );
        _;
    }

    modifier validProject(uint256 _projectId) {
        if (_projectId > currentProjectId || _projectId <= 0) {
            revert InvalidProjectId();
        }
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

    ////////////////////////////////////////////////////
	//////////////// CONTRACT ERRORS //////////////////
	//////////////////////////////////////////////////
	/**
	 * @dev general errors
	 */
    error InvalidProjectId();
    error ZeroAddress();

	/**
	 * @dev addProject errors
	 */

	error InvalidProjectSoftCap();
	error InvalidProjectHardCap();
	error InvalidProjectMinInvestment();
	error InvalidProjectMaxInvestment();
    error TokenPriceMustBePositive();
    error TokenForSaleMustBePositive();
	error InvalidProjectTimeframe();

	/**
	 * @dev investProject errors
	 */
    error VAssetNotAcceptedByProject();

	/**
	 * @dev joinWhitelist errors
	 */
	error AlreadyWhitelisted();	
	error MinReserveAmountNotReached();

	////////////////////////////////////////////////////
	//////////// TRANSACTIONAL FUNCTIONS //////////////
	//////////////////////////////////////////////////
    constructor(address _slpxAddress) Ownable(_msgSender()) {
        slpxAddress = _slpxAddress;
    }

	/**
	 * 
	 * @notice Project owner lists project on IDO
	 */
    function addProject(
        address _tokenAddress,
        uint256 _pricePerToken,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _minInvest,
        uint256 _maxInvest,
        uint256 _hardCapAmount,
        uint256 _softCapAmount,
        uint256 _rewardRate,
        address _acceptedVAsset
    ) public notZeroAddress(_tokenAddress) {
		// constraint check
		if (_hardCapAmount <= 0 
		|| _hardCapAmount <= _softCapAmount) {
			revert InvalidProjectHardCap();	
		}
		if (_softCapAmount <= 0) {
			revert InvalidProjectSoftCap();
		}
		if (_maxInvest <= 0 
		|| _maxInvest > _hardCapAmount
		|| _maxInvest < _minInvest) {
			revert InvalidProjectMaxInvestment();
		} 
		if (_minInvest <= 0) {
			revert InvalidProjectMinInvestment();
		}
		if (_startTime < block.timestamp
		|| _startTime < _endTime) {
			revert InvalidProjectTimeframe();
		}	
		
		// create project & update state
		uint256 newProjectId = currentProjectId;
        Project memory newProject = Project({
            projectId: newProjectId,
            projectOwner: _msgSender(),
            tokenAddress: _tokenAddress,
            pricePerToken: _pricePerToken,
            startTime: _startTime,
            endTime: _endTime,
            raisedAmount: 0,
            minInvest: _minInvest,
            maxInvest: _maxInvest,
            hardCapAmount: _hardCapAmount,
            softCapAmount: _softCapAmount,
            acceptedVAsset: _acceptedVAsset,
            rewardRate: _rewardRate
        });

        projects[currentProjectId] = newProject;

        emit ProjectCreated(
            _msgSender(),
            _tokenAddress,
			newProjectId,
            _pricePerToken,
            _startTime,
            _endTime
        );

        currentProjectId++;
    }

    function withdrawFund(uint256 _projectId) public onlyProjectOwner(_projectId) {
        require(
            block.timestamp > projects[_projectId].endTime,
            "Project is still active"
        );
        uint256 projectRaisedAmount = projects[_projectId].raisedAmount;
        payable(_msgSender()).transfer(projectRaisedAmount);
        projects[_projectId].raisedAmount = 0;
        emit ProjectWithdrawn(_msgSender(), _projectId);
    }

    function investProject(
        uint256 projectId,
        uint256 amount
    )
        public
        validProject(projectId)
        IDOStillAvailable(projectId)
        needToBeWhitelisted(_msgSender(), projectId)
    {
        /**
         * @dev cache _msgSender() and address(this) once
         * to limit reading from state too many
         */
        address investor = _msgSender();
        address contractAddr = address(this);

        // Check vAsset allowance
		address vAssetAddress = getAcceptedVAsset(projectId);
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

	/**
	 * 
	 * @notice join a project's whitelist
	 * @notice enrolling in a project's whitelist is a prerequisite before investing money into it
	 * @notice this step requires user to deposit 50% of 
	 * project's min. investment amount as a proof of engagement
	 * @notice access role: anyone except project's owner
	 * @param projectId ID of the project to join
	 */
    function joinWhitelist(
        uint256 projectId
    )
        external
        validProject(projectId)
        IDOStillAvailable(projectId)
        // notWhitelisted(_msgSender(), _projectId) // replace with in-function check
    {
		address investor = _msgSender();
		address IDOAddr = address(this);

		if (whitelistedAddresses[projectId][investor]) {
			revert AlreadyWhitelisted();
		}
		
		// transfers reserve amount (50% of project's min investment) from investor to this contract
		address vAsset = getAcceptedVAsset(projectId);
		uint256 reserveAmount = getReserveInvestment(projectId);
		if (IERC20(vAsset).allowance(investor, IDOAddr) < reserveAmount) {
			revert MinReserveAmountNotReached();
		}
		IERC20(vAsset).transferFrom(investor, IDOAddr, reserveAmount);
		
		// update states
		balances[investor][projectId] += reserveAmount;
		whitelistedAddresses[projectId][investor] = true;
        projects[projectId].raisedAmount += reserveAmount;
        balances[_msgSender()][projectId] += reserveAmount;

        emit Whitelisted(_msgSender(), projectId);
    }

	////////////////////////////////////////////////////
	//////////////// GETTERS FUNCTIONS ////////////////
	//////////////////////////////////////////////////
    /**
     * @dev view functions
     * @param _projectId the project id number
     * @param _address the user adr that check for whitelisted 
	 * or not on the corresponding project
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
		return (projects[projectId].acceptedVAsset == vAssetAddress);
    }

    function getTimeLeftUntilProjecctEnd(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].endTime - block.timestamp;
    }

    function getCurrentProjectId() public view returns (uint256) {
        return currentProjectId;
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

	function getAcceptedVAsset(
		uint256 projectId
	)
		public view returns (address) {
		return projects[projectId].acceptedVAsset;
	}
	
	////////////////////////////////////////////////////
	//////////////// SETTERS FUNCTIONS ////////////////
	//////////////////////////////////////////////////
    function setSlpxAddress(address _slpxAddress) public onlyOwner {
        slpxAddress = _slpxAddress;
    }

    function setIDOFeeRate(uint256 _IDOfeeRate) public onlyOwner {
        IDOFeeRate = _IDOfeeRate;
    }
}
