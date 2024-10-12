// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

contract IDO is Ownable, ReentrancyGuard {
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

    modifier IsInIDOTimeFrame(uint256 projectId) {
        if (block.timestamp < projects[projectId].startTime) {
            revert ProjectIDOHasNotStarted();
        }
        if (block.timestamp > projects[projectId].endTime) {
            revert ProjectIDOHasEnded();
        }
        _;
    }

    modifier needToBeWhitelisted(uint256 projectId, address investor) {
        if (!whitelistedAddresses[projectId][investor]) {
            revert UserNotWhitelisted();
        }
        _;
    }

    modifier notWhitelisted(uint256 projectId, address investor) {
        if (!whitelistedAddresses[projectId][investor]) {
			revert AlreadyWhitelisted();
		}
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
     * @dev joinWhitelist errors
     */
    error AlreadyWhitelisted();
    error NotEnoughERC20Allowance();
    error ProjectIDOHasNotStarted();
    error ProjectIDOHasEnded();

    /**
     * @dev investProject errors
     */
    // error NotEnoughERC20Allowance(); also use in investProject func.
    error MinInvestmentNotReached();
    error MaxInvestmentExceeded();
    error HardCapExceeded();
    error UserNotWhitelisted();

    /**
     * @dev _takeInvestorMoney errors
     */
    error ERC20TransferFailed();
    ////////////////////////////////////////////////////
    //////////// TRANSACTIONAL FUNCTIONS //////////////
    //////////////////////////////////////////////////
    constructor(address _slpxAddress) Ownable(_msgSender()) {
        setSlpxAddress(_slpxAddress);
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
        if (_hardCapAmount <= 0 || _hardCapAmount <= _softCapAmount) {
            revert InvalidProjectHardCap();
        }
        if (_softCapAmount <= 0) {
            revert InvalidProjectSoftCap();
        }
        if (
            _maxInvest <= 0 ||
            _maxInvest > _hardCapAmount ||
            _maxInvest < _minInvest
        ) {
            revert InvalidProjectMaxInvestment();
        }
        if (_minInvest <= 0) {
            revert InvalidProjectMinInvestment();
        }
        if (_startTime < block.timestamp || _startTime > _endTime) {
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

        projects[newProjectId] = newProject;

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

    function withdrawFund(
        uint256 _projectId
    ) public onlyProjectOwner(_projectId) nonReentrant {
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
        IsInIDOTimeFrame(projectId)
        needToBeWhitelisted(projectId, _msgSender())
        nonReentrant
    {
		address investor = _msgSender();

		// check
        Project memory project = getProjectFullDetails(projectId);
        uint256 reserveAmount = getInvestedAmount(projectId, investor);
        uint256 totalInvestAmount = reserveAmount + amount;

        if (totalInvestAmount < project.minInvest) {
            revert MinInvestmentNotReached();
        }

        if (totalInvestAmount > project.maxInvest) {
            revert MaxInvestmentExceeded();
        }

        if (project.raisedAmount + totalInvestAmount > project.hardCapAmount) {
            revert HardCapExceeded();
        }

		emit Invested(investor, projectId, amount);

		_takeInvestorMoneyForProject(projectId, investor, amount);
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
        IsInIDOTimeFrame(projectId)
        nonReentrant
    {
		address investor = _msgSender();

        if (whitelistedAddresses[projectId][investor]) {
            revert AlreadyWhitelisted();
        }

        emit Whitelisted(_msgSender(), projectId);
		whitelistedAddresses[projectId][investor] = true;

        // transfers reserve amount (50% of project's min investment) from investor to this contract
        uint256 reserveAmount = getReserveInvestment(projectId);
        _takeInvestorMoneyForProject(projectId, _msgSender(), reserveAmount);
    }

    function _takeInvestorMoneyForProject(
		uint256 projectId,
        address investor,
        uint256 amount
    ) internal {
		address vAsset = getAcceptedVAsset(projectId);
		uint256 allowanceAmount = IERC20(vAsset).allowance(investor, address(this));	

		// check
        if (allowanceAmount < amount) {
            revert NotEnoughERC20Allowance();
        }

        // update states
        balances[investor][projectId] += amount;
        projects[projectId].raisedAmount += amount;

        // interactions
        bool success = IERC20(vAsset).transferFrom(
            investor,
            address(this),
            amount
        );
        if (!success) {
            revert ERC20TransferFailed();
        }
    }

    ////////////////////////////////////////////////////
    //////////////// GETTER FUNCTIONS /////////////////
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

    function getProjectRaisedAmount(
        uint256 projectId
    ) public view returns (uint256) {
        return projects[projectId].raisedAmount;
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

	function getProjectMinInvest(
		uint256 projectId
	) public view validProject(projectId) returns (uint256) {
		return projects[projectId].minInvest;
	}

	function getProjectMaxInvest(
		uint256 projectId
	) public view validProject(projectId) returns (uint256) {
		return projects[projectId].maxInvest;
	}

    function isProjectActive(
        uint256 _projectId
    ) public view validProject(_projectId) returns (bool) {
        return (block.timestamp > projects[_projectId].endTime);
    }

    function isVAssetAcceptedByProject(
        uint256 projectId,
        address vAssetAddress
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
        uint256 _projectId,
        address _userAdr
    ) public view validProject(_projectId) returns (uint256) {
        uint256 investedAmount = balances[_userAdr][_projectId];
        return investedAmount;
    }

    function getReserveInvestment(
        uint256 _projectId
    ) public view validProject(_projectId) returns (uint256) {
        return projects[_projectId].minInvest / 2;
    }

    function getAcceptedVAsset(
        uint256 projectId
    ) public view returns (address) {
        return projects[projectId].acceptedVAsset;
    }

    ////////////////////////////////////////////////////
    //////////////// SETTER FUNCTIONS /////////////////
    //////////////////////////////////////////////////
    function setSlpxAddress(
        address _slpxAddress
    ) public notZeroAddress(_slpxAddress) onlyOwner {
        slpxAddress = _slpxAddress;
    }

    function setIDOFeeRate(uint256 _IDOfeeRate) public onlyOwner {
        IDOFeeRate = _IDOfeeRate;
    }
}
