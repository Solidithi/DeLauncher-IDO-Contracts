// SPDX-License-Idenifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface IIDO {
    /**
	 * 
	 * @notice Project owner lists project on IDO
	 * @notice access role: anyone
	 * @param tokenAddress .
	 * @param pricePerToken .
	 * @param startTime project launchpad start time
	 * @param endTime project launcchpad end time
	 * @param minInvest .
	 * @param maxInvest .
	 * @param hardCapAmount .
	 * @param softCapAmount .
	 * @param rewardRate .
	 * @param acceptedVAsset .
	 */
	function addProject(
		address tokenAddress,
        uint256 pricePerToken,
        uint256 startTime,
        uint256 endTime,
        uint256 minInvest,
        uint256 maxInvest,
        uint256 hardCapAmount,
        uint256 softCapAmount,
        uint256 rewardRate,
        address acceptedVAsset
	) external;

	/**
	 * 
	 * @notice withdraw raised fund of a project
	 * @notice access role: project owner
	 * @param projectId ID of the project to withdraw from
	 * 
	 */
    function withDrawFund(uint256 projectId) external;
	

	/**
	 * 
	 * @notice join a project's whitelist
	 * @notice enrolling in a project's whitelist is a prerequisite before investing money into it
	 * @notice this step requires user to deposit 50% of 
	 * project's min. investment amount as a proof of engagement
	 * @notice access role: anyone except project's owner
	 * @param projectId .
	 */
	function joinWhiteList(uint256 projectId) external;	

	/**
	 * 
	 * @notice invest vAsset in exchange of project token + reward
	 * @notice access role: anyone
	 * @param projectId .
	 * @param amount .
	 */
	function investProject(
		uint256 projectId,
		uint256 amount
	) external;

	/**
	 * 
	 * @notice investor withdraws the project tokens they purchased + reward
	 * @notice access role: investor 
	 * @param projectId .
	 */
	function withdrawProjectTokens(uint256 projectId) external;
}
