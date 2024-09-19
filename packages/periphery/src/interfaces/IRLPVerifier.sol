// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@votemarket/interfaces/IOracle.sol";

interface IRLPVerifier {
    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32 stateRootHash);
    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.VotedSlope memory userSlope);

    function setPointData(address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.Point memory weight);
}
