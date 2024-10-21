// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IL1Block {
    function hash() external view returns (bytes32);
    function number() external view returns (uint256);
    function timestamp() external view returns (uint256);
}
