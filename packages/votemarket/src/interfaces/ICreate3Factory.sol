// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt) external view returns (address);
}
