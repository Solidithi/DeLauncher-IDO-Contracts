// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import "../interfaces/ISlpx.sol";

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

    /**
     * @dev use 4 DECIMALS for numbers related to rate
     * example: 1000 is equivalent to 1 (100 %)
     * example: 10 is equivalent to 0.001 (1 %)
     */
    uint256 public constant RATE_DECIMALS = 4;

    // IDO fee rate
    uint256 public constant IDO_FEE_RATE = 50; // equals to 0.005 if RATE_DECIMALS is 4

    // Address of Bifrost SLPX contract
    address public immutable slpxAddress;
    ISlpx public immutable slpxContract;

    // Withdraw state
    bool public withdrawed;

    // Project ID value counter
    mapping(address => uint256) private userDepositAmount;
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
        uint256 amount
    );
    event ProjectWithdrawn(
        address indexed user,
        uint256 indexed projectId,
        uint256 amount
    );
    event Redeemed(
        address indexed user,
        uint256 indexed projectId,
        uint256 amount
    );

    ////////////////////////////////////////////////////
    /////////////// CONTRACT MODIFIERS ////////////////
    //////////////////////////////////////////////////
    modifier onlyProjectOwner() {
        if (_msgSender() != projectDetail.projectOwner) {
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

    modifier isInWithdrawTimeFrame() {
        if (block.timestamp < projectDetail.endTime) {
            revert ProjectStillActive();
        }
        _;
    }

    modifier softCapReached() {
        if (projectDetail.raisedAmount < projectDetail.softCapAmount) {
            revert SoftCapNotReach();
        }
        _;
    }

    modifier notWithdraw(){
        if (withdrawed){
            revert AlreadyWithdraw();
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
    error HardCapExceeded();

    /**
     * @dev investProject errors
     */
    // error NotEnoughERC20Allowance(); also use in investProject func.
    error MinInvestmentNotReached();
    error MaxInvestmentExceeded();
    error UserNotWhitelisted();

    /**
     * @dev _takeInvestorMoney errors
     */
    error ERC20TransferFailed();

    /**
     * @dev project owner withdraw errors
     */
    error ProjectStillActive();
    error SoftCapNotReach();
    error AlreadyWithdraw();

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
        withdrawed = false;
        slpxAddress = _slpxAddress;
        slpxContract = ISlpx(slpxAddress);
    }

    /**
     *
     * @notice Project owner lists project on IDO
     */

    function withdrawFund()
        external
        onlyProjectOwner
        nonReentrant
        isInWithdrawTimeFrame
        softCapReached
        notWithdraw
    {
        uint256 withdrawAmount = getWithdrawAmount();

        bool success = IERC20(projectDetail.acceptedVAsset).transfer(
            _msgSender(),
            withdrawAmount
        );

        if (!success) {
            revert ERC20TransferFailed();
        }

        withdrawed = true;

        emit ProjectWithdrawn(
            _msgSender(),
            projectDetail.projectId,
            withdrawAmount
        );
    }

    function slpxWithdrawFund() 
        external 
        onlyProjectOwner
        nonReentrant
        isInWithdrawTimeFrame
        softCapReached
        notWithdraw
    {
        uint256 withdrawAmount = getWithdrawAmount();

        slpxContract.redeemAsset(projectDetail.acceptedVAsset, withdrawAmount, _msgSender());

        withdrawed = true;

        emit ProjectWithdrawn(
            _msgSender(),
            projectDetail.projectId,
            withdrawAmount
        );
    }

    function investProject(
        uint256 amount
    ) external isInIDOTimeFrame needToBeWhitelisted(_msgSender()) nonReentrant {
        address investor = _msgSender();

        // check
        ProjectDetail memory project = getProjectFullDetails();
        uint256 reserveAmount = getUserDepositAmount(investor);
        uint256 totalInvestAmount = reserveAmount + amount;

        if (totalInvestAmount < project.minInvest) {
            revert MinInvestmentNotReached();
        }

        if (totalInvestAmount > project.maxInvest) {
            revert MaxInvestmentExceeded();
        }

        emit Invested(investor, project.projectId, amount);
        projectDetail.raisedAmount += totalInvestAmount;
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

        if (getProjectRaisedAmount() >= getProjectHardCapAmount()) {
            revert HardCapExceeded();
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
        userDepositAmount[investor] += amount;

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
    /////////////////// REDEEM  ///////////////////////
    //////////////////////////////////////////////////
    function redeemTokens()
        external
        isInWithdrawTimeFrame
        softCapReached
        needToBeWhitelisted(_msgSender())
        nonReentrant
    {
        address investor = _msgSender();
        uint256 redeemAmount = getRedeemAmount();

        // Get the reward based on the rewardRate and total claimable amount
        uint256 rewardAmount = (redeemAmount * projectDetail.rewardRate);

        // Total amount to be transferred (claimable tokens + reward)
        uint256 totalTransferAmount = redeemAmount + rewardAmount;

        // Transfer the claimable tokens and reward to the user
        bool success = IERC20(projectDetail.tokenAddress).transfer(
            investor,
            totalTransferAmount
        );

        if (!success) {
            revert ERC20TransferFailed();
        }

        emit Redeemed(investor, projectDetail.projectId, totalTransferAmount);
    }

    ////////////////////////////////////////////////////
    ///////////////////// Refund //////////////////////
    //////////////////////////////////////////////////
    function refundToken()
        external
        isInWithdrawTimeFrame
        needToBeWhitelisted(_msgSender())
        nonReentrant
    {
        address investor = _msgSender();
        uint256 investAmount = userDepositAmount[investor];

        bool refundSuccess = IERC20(projectDetail.acceptedVAsset).transfer(
            investor,
            investAmount
        );

        if (!refundSuccess) {
            revert ERC20TransferFailed();
        }

        emit Redeemed(investor, projectDetail.projectId, investAmount);
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

    function getProjectsoftCapReached() public view returns (bool) {
        return projectDetail.raisedAmount >= projectDetail.softCapAmount;
    }

    function getProjectMinInvest() public view returns (uint256) {
        return projectDetail.minInvest;
    }

    function getProjectMaxInvest() public view returns (uint256) {
        return projectDetail.maxInvest;
    }

    function isProjectFullyToppedUp() public view returns (bool) {
        uint256 alreadyToppedUp = getProjectTokenToppedUpAmt();

        uint256 amtToTopUp = getAmountToTopUp();

        return alreadyToppedUp >= amtToTopUp;
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

    function getUserDepositAmount(
        address _userAdr
    ) public view returns (uint256) {
        return userDepositAmount[_userAdr];
    }

    // util function
    function getAmountToTopUp() public view returns (uint256) {
        uint256 vTokenHardCap = getProjectHardCapAmount();
        uint8 projectTokenDecimals = IERC20(getProjectTokenAddress()).decimals();
        uint256 toBeToppedUp = (vTokenHardCap * (10 ** projectTokenDecimals)) /
            projectDetail.pricePerToken;
        return toBeToppedUp;
    }

    function getProjectTokenToppedUpAmt() public view returns (uint256) {
        return IERC20(getProjectTokenAddress()).balanceOf(address(this));
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

    function getProjectTokenAddress() public view returns (address) {
        return projectDetail.tokenAddress;
    }

    function getVAssetAddress() public view returns (address) {
        return projectDetail.acceptedVAsset;
    }

    function getWithdrawAmount() public view returns (uint256) {
        uint256 raisedAmount = getProjectRaisedAmount();
        uint256 IDOFeeAmount = (raisedAmount * IDO_FEE_RATE) /
            10 ** RATE_DECIMALS;
        uint256 withdrawAmount = raisedAmount - IDOFeeAmount;
        return withdrawAmount;
    }

    function getRedeemAmount() public view returns (uint256) {
        uint256 investAmount = userDepositAmount[_msgSender()];
        uint256 redeemAmount = (investAmount * (10 ** RATE_DECIMALS)) /
            projectDetail.pricePerToken;
        return redeemAmount;
    }

    function getProjectOwner() public view returns (address) {
        return projectDetail.projectOwner;
    }

    function getPricePerToken() public view returns (uint256) {
        return projectDetail.pricePerToken;
    }

    function getProjectWithdrawState() public view returns (bool) {
        return withdrawed;
    }

    ////////////////////////////////////////////////////
    //////////////// SETTER FUNCTIONS /////////////////
    //////////////////////////////////////////////////
}
