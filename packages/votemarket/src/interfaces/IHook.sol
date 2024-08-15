// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IHook {
    function validateHook() external view returns (bool);
    function doSomething(
        uint256 campaignId,
        uint256 chainId,
        address rewardToken,
        uint256 epoch,
        uint256 amount,
        bytes calldata hookData
    ) external;
}
