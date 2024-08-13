// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// Mock contracts for testing hooks
contract MockHook {
    function validateHook() external pure returns (bool) {
        return true;
    }

    function doSomething(uint campaignId, uint epoch, bytes calldata) external pure {}
}

contract MockInvalidHook {
    function validateHook() external pure returns (bool) {
        return false;
    }

    function doSomething(uint campaignId, uint epoch, bytes calldata) external pure {}
}
