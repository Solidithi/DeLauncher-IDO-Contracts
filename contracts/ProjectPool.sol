// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {console} from "forge-std/console.sol";

contract ProjectPool is Ownable, ReentrancyGuard {
    struct ProjectDetail {
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
    // project detail
    ProjectDetail internal projectDetail;
    uint256 internal currentProjectId = 1;

    /**
     * @dev use 4 DECIMALS for numbers related to rate
     * example: 1000 is equivalent to 1 (100 %)
     * example: 10 is equivalent to 0.001 (1 %)
     */
    uint256 public constant RATE_DECIMALS = 4;

    // IDO fee rate
    uint256 public constant IDOFeeRate = 50; // equals to 0.0005 if RATE_DECIMALS is 4

    // Address of Bifrost SLPX contract
    address public immutable slpxAddress;


    // Project ID value counter

    mapping(address => uint256) private investedAmount;
    mapping(address => bool) private whitelistedAddresses;

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
    modifier onlyProjectOwner() {
        if (_msgSender() == projectDetail.projectOwner) {
            revert NotProjectOwner();
        }
        _;
    }

    modifier notZeroAddress(address a) {
        if (a == address(0)) {
            revert ZeroAddress();
        }
        _;
    }

    modifier isInIDOTimeFrame() {
		console.log("Now is: ", block.timestamp);
		console.log("Project start time:", projectDetail.startTime);
        if (block.timestamp < projectDetail.startTime) {
            revert ProjectIDOHasNotStarted();
        }
        if (block.timestamp > projectDetail.endTime) {
            revert ProjectIDOHasEnded();
        }
        _;
    }

    modifier needToBeWhitelisted(address investor) {
        if (!whitelistedAddresses[investor]) {
            revert UserNotWhitelisted();
        }
        _;
    }

    modifier notWhitelisted(address investor) {
        if (!whitelistedAddresses[investor]) {
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
    error NotProjectOwner();

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
    constructor(
        address projectOwner,
        address tokenAddress,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime,
        uint256 minInvest,
        uint256 maxInvest,
        uint256 hardCapAmount,
        uint256 softCapAmount,
        uint256 rewardRate,
        address acceptedVAsset,
		address _slpxAddress
    ) notZeroAddress(projectOwner) Ownable(projectOwner) {
        // constraint check
        if (hardCapAmount <= 0 || hardCapAmount <= softCapAmount) {
            revert InvalidProjectHardCap();
        }
        if (softCapAmount <= 0) {
            revert InvalidProjectSoftCap();
        }
        if (
            maxInvest <= 0 || maxInvest > hardCapAmount || maxInvest < minInvest
        ) {
            revert InvalidProjectMaxInvestment();
        }
        if (minInvest <= 0) {
            revert InvalidProjectMinInvestment();
        }
        if (startTime < block.timestamp || startTime > endTime) {
            revert InvalidProjectTimeframe();
        }

        projectDetail.projectOwner = projectOwner;
        projectDetail.tokenAddress = tokenAddress;
        projectDetail.pricePerToken = pricePerToken;
        projectDetail.startTime = startTime;
        projectDetail.endTime = endTime;
        projectDetail.raisedAmount = 0;
        projectDetail.minInvest = minInvest;
        projectDetail.maxInvest = maxInvest;
        projectDetail.hardCapAmount = hardCapAmount;
        projectDetail.softCapAmount = softCapAmount;
        projectDetail.acceptedVAsset = acceptedVAsset;
        projectDetail.rewardRate = rewardRate;
        slpxAddress = _slpxAddress;
    }

    /**
     *
     * @notice Project owner lists project on IDO
     */

    function withdrawFund(
        uint256 _projectId
    ) public onlyProjectOwner nonReentrant {
        require(
            block.timestamp > projectDetail.endTime,
            "Project is still active"
        );
        uint256 projectRaisedAmount = projectDetail.raisedAmount;
        payable(_msgSender()).transfer(projectRaisedAmount);
        projectDetail.raisedAmount = 0;
        emit ProjectWithdrawn(_msgSender(), _projectId);
    }

    function investProject(
        uint256 amount
    ) public isInIDOTimeFrame needToBeWhitelisted(_msgSender()) nonReentrant {
        address investor = _msgSender();

        // check
        ProjectDetail memory project = getProjectFullDetails();
        uint256 reserveAmount = getInvestedAmount(investor);
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

        emit Invested(investor, project.projectId, amount);

        _takeInvestorVAsset(investor, amount);
    }

    /**
     *
     * @notice join a project's whitelist
     * @notice enrolling in a project's whitelist is a prerequisite before investing money into it
     * @notice this step requires user to deposit 50% of
     * project's min. investment amount as a proof of engagement
     * @notice access role: anyone except project's owner
     */
    function joinWhitelist() external isInIDOTimeFrame nonReentrant {
        address investor = _msgSender();

        if (whitelistedAddresses[investor]) {
            revert AlreadyWhitelisted();
        }

        emit Whitelisted(_msgSender(), projectDetail.projectId);
        whitelistedAddresses[investor] = true;

        // transfers reserve amount (50% of project's min investment) from investor to this contract
        uint256 reserveAmount = getReserveInvestment();
        _takeInvestorVAsset(_msgSender(), reserveAmount);
    }

    function _takeInvestorVAsset(address investor, uint256 amount) internal {
        address vAsset = getAcceptedVAsset();
        uint256 allowanceAmount = IERC20(vAsset).allowance(
            investor,
            address(this)
        );

        // check
        if (allowanceAmount < amount) {
            revert NotEnoughERC20Allowance();
        }

        // update states
        investedAmount[investor] += amount;
        projectDetail.raisedAmount += amount;

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
     * @notice check if a user is whitelisted in the current project
     * @param _address the user addr that check for whitelisted
     *
     */
    function isWhitelisted(address _address) public view returns (bool) {
        return whitelistedAddresses[_address];
    }

    function getProjectFullDetails()
        public
        view
        returns (ProjectDetail memory)
    {
        return projectDetail;
    }

    function getProjectRaisedAmount() public view returns (uint256) {
        return projectDetail.raisedAmount;
    }

    function getProjectHardCapAmount() public view returns (uint256) {
        return projectDetail.hardCapAmount;
    }

    function getProjectSoftCapAmount() public view returns (uint256) {
        return projectDetail.softCapAmount;
    }

    function getProjectMinInvest() public view returns (uint256) {
        return projectDetail.minInvest;
    }

    function getProjectMaxInvest() public view returns (uint256) {
        return projectDetail.maxInvest;
    }

    function isProjectActive() public view returns (bool) {
        return (block.timestamp > projectDetail.endTime);
    }

    function isVAssetAcceptedByProject(
        address vAssetAddress
    ) public view returns (bool) {
        return (vAssetAddress == projectDetail.acceptedVAsset);
    }

    function getTimeLeftUntilProjecctEnd() public view returns (uint256) {
        return projectDetail.endTime - block.timestamp;
    }

    function getCurrentProjectId() public view returns (uint256) {
        return currentProjectId;
    }

    function getInvestedAmount(address _userAdr) public view returns (uint256) {
        return investedAmount[_userAdr];
    }

    function getReserveInvestment() public view returns (uint256) {
        return projectDetail.minInvest / 2;
    }

    function getAcceptedVAsset() public view returns (address) {
        return projectDetail.acceptedVAsset;
    }

    function getProjectDetail() public view returns (ProjectDetail memory) {
        return projectDetail;
    }

	function getProjectStartTime() public view returns (uint256) {
		return projectDetail.startTime;
	}

	function getProjectEndTime() public view returns (uint256) {
		return projectDetail.endTime;
	}

    ////////////////////////////////////////////////////
    //////////////// SETTER FUNCTIONS /////////////////
    //////////////////////////////////////////////////
}
