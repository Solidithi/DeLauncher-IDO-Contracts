// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

interface IProjectPoolFactory {
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
    function createProjectPool(
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
    ) external returns (uint256);
    
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
     * 
     */
    function joinWhiteList(uint256 projectId) external;

    /**
     * 
     * @notice get project pool address
     * @param projectId .
     * @return project pool address
     *  
     */    
    function getProjectPoolAddress(uint256 projectId) external view returns (address);

	function getCurrentProjectId() external view returns (uint256);

    /**
     * 
     * @notice check if pool is valid
     * @param poolAddress .
     * @return true if pool is valid
     *  
     */
    function checkPoolIsValid(address poolAddress) external view returns (bool);

    /**
     * 
     * @notice set slpx address
     * @param _slpxAddress .
     *  
     */
    function setSlpxAddress(address _slpxAddress) external;

}  