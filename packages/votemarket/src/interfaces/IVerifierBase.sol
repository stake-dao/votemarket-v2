// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IVerifierBase {
    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32);
    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof) external returns (IOracle.VotedSlope memory);
    function setPointData(address gauge, uint256 epoch, bytes calldata proof) external returns (IOracle.Point memory);
}
