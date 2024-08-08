// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IHook {
    function validateHook() external view returns (bool);
    function doSomething(bytes calldata) external;
}
