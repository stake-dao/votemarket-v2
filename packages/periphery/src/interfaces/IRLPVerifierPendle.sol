// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@votemarket/src/interfaces/IPendleOracle.sol";

interface IRLPVerifierPendle {
    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32 stateRootHash);
    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IPendleOracle.VotedSlope memory userSlope);

    function setPointData(address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IPendleOracle.Point memory weight);
}
