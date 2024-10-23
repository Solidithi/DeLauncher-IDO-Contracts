// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

interface IProjectPool {
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
    /**
     * @notice Emitted when a user is whitelisted for a project.
     * @param user Address of the user being whitelisted.
     * @param projectId ID of the project.
     */
    event Whitelisted(address indexed user, uint256 indexed projectId);

    /**
     * @notice Emitted when a project is created.
     * @param projectOwner Address of the project owner.
     * @param tokenAddress Address of the token used for the project.
     * @param projectId ID of the project.
     * @param pricePerToken Price of each token.
     * @param startTime Start time of the project.
     * @param endTime End time of the project.
     */
    event ProjectCreated(
        address indexed projectOwner,
        address indexed tokenAddress,
        uint256 projectId,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime
    );

    /**
     * @notice Emitted when a user invests in a project.
     * @param user Address of the user making the investment.
     * @param projectId ID of the project.
     * @param amount Amount invested.
     */
    event Invested(
        address indexed user,
        uint256 indexed projectId,
        uint256 amount
    );

    /**
     * @notice Emitted when the project owner withdraws funds.
     * @param user Address of the project owner.
     * @param projectId ID of the project.
     * @param amount Amount withdrawn.
     */
    event ProjectWithdrawn(
        address indexed user,
        uint256 indexed projectId,
        uint256 amount
    );

    /**
     * @notice Emitted when tokens are redeemed by the user.
     * @param user Address of the user redeeming tokens.
     * @param projectId ID of the project.
     * @param amount Amount of tokens redeemed.
     */
    event Redeemed(
        address indexed user,
        uint256 indexed projectId,
        uint256 amount
    );

    /**
     * @notice Returns the full details of the project.
     * @return ProjectDetail The project detail structure containing all relevant project data.
     */
    function getProjectFullDetails()
        external
        view
        returns (ProjectDetail memory);

    /**
     * @notice Returns the total amount raised for the project.
     * @return uint256 The raised amount in vAssets.
     */
    function getProjectRaisedAmount() external view returns (uint256);

    /**
     * @notice Returns the hard cap amount for the project.
     * @return uint256 The maximum amount of vAssets the project can raise.
     */
    function getProjectHardCapAmount() external view returns (uint256);

    /**
     * @notice Checks if a user is whitelisted for the project.
     * @param _address The address to check.
     * @return bool True if the user is whitelisted, false otherwise.
     */
    function isWhitelisted(address _address) external view returns (bool);

    /**
     * @notice Returns the minimum investment amount for the project.
     * @return uint256 The minimum amount an individual can invest.
     */
    function getProjectMinInvest() external view returns (uint256);

    /**
     * @notice Returns the maximum investment amount for the project.
     * @return uint256 The maximum amount an individual can invest.
     */
    function getProjectMaxInvest() external view returns (uint256);

    /**
     * @notice Checks if the project is currently active.
     * @return bool True if the project is active, false if the project has ended.
     */
    function isProjectActive() external view returns (bool);

    function isProjectFullyToppedUp() external view returns (bool);

    /**
     * @notice Returns the remaining time until the project ends.
     * @return uint256 The time left in seconds until the project ends.
     */
    function getTimeLeftUntilProjecctEnd() external view returns (uint256);

    /**
     * @notice Returns the deposit amount for a specific user.
     * @param _userAdr The user's address.
     * @return uint256 The total deposit amount.
     */
    function getUserDepositAmount(
        address _userAdr
    ) external view returns (uint256);

    /**
     * @notice Returns the accepted vAsset address for the project.
     * @return address The address of the vAsset accepted in the project.
     */
    function getAcceptedVAsset() external view returns (address);

    /**
     * @notice Returns the project owner address.
     * @return address The project owner's address.
     */
    function getProjectOwner() external view returns (address);

    function getAmountToTopUp() external view returns (uint256);

    function getProjectTokenAddress() external view returns (address);

    function getVAssetAddress() external view returns (address);

    function getProjectTokenToppedUpAmt() external view returns (uint256);

	function getProjectStartTime() external view returns (uint256);

	function getProjectEndTime() external view returns (uint256);

    /**
     * @notice Allows the project owner to withdraw funds after the project has ended.
     */
    function withdrawFund() external;

    /**
     * @notice Allows a user to invest in the project.
     * @param amount The amount of vAssets to invest.
     */
    function investProject(uint256 amount) external;

    /**
     * @notice Allows a user to join the whitelist of a project by depositing 50% of the minimum investment.
     */
    function joinWhitelist() external;

    /**
     * @notice Allows users to redeem their claimable tokens after the project has ended.
     */
    function redeemTokens() external;

    /**
     * @notice Allows users to request a refund of their investment if applicable.
     */
    function refundToken() external;
}
