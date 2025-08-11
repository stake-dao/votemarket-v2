// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IRLPVerifierPendle.sol";

abstract contract RLPVerifierPendle {
    function setBlockData(address verifier, bytes calldata blockHeader, bytes calldata proof)
        external
        payable
        returns (bytes32 stateRootHash)
    {
        stateRootHash = IRLPVerifierPendle(verifier).setBlockData(blockHeader, proof);
    }

    function setAccountData(address verifier, address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        payable
        returns (IPendleOracle.VotedSlope memory userSlope)
    {
        userSlope = IRLPVerifierPendle(verifier).setAccountData(account, gauge, epoch, proof);
    }

    function setPointData(address verifier, address gauge, uint256 epoch, bytes calldata proof)
        external
        payable
        returns (IPendleOracle.Point memory weight)
    {
        weight = IRLPVerifierPendle(verifier).setPointData(gauge, epoch, proof);
    }
}
