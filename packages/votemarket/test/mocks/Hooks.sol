// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";

// Mock contracts for testing hooks
contract MockHook {
    address public immutable rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function validateHook() external pure returns (bool) {
        return true;
    }

    function doSomething(
        uint256 campaignId,
        uint256 chainId,
        address rewardToken,
        uint256 epoch,
        uint256 amount,
        bytes calldata hookData
    ) external {}

    function returnFunds(address token, address to, uint256 amount) external {
        SafeTransferLib.safeTransfer(token, to, amount);
    }
}

contract MockInvalidHook {
    address public immutable rewardToken;

    constructor(address _rewardToken) {
        rewardToken = _rewardToken;
    }

    function validateHook() external pure returns (bool) {
        return false;
    }

    function doSomething(
        uint256 campaignId,
        uint256 chainId,
        address rewardToken,
        uint256 epoch,
        uint256 amount,
        bytes calldata hookData
    ) external {}

    function returnFunds(address token, address to, uint256 amount) external {
        SafeTransferLib.safeTransfer(token, to, amount);
    }
}
