// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

// Mock contracts for testing hooks
contract MockHook {
    function validateHook() external pure returns (bool) {
        return true;
    }
}

contract MockInvalidHook {
    function validateHook() external pure returns (bool) {
        return false;
    }
}