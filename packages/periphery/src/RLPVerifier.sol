// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IRLPVerifier.sol";

abstract contract RLPVerifier {
    function setBlockData(address verifier, bytes calldata blockHeader, bytes calldata proof)
        external
        returns (bytes32 stateRootHash)
    {
        stateRootHash = IRLPVerifier(verifier).setBlockData(blockHeader, proof);
    }

    function setAccountData(address verifier, address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.VotedSlope memory userSlope)
    {
        userSlope = IRLPVerifier(verifier).setAccountData(account, gauge, epoch, proof);
    }

    function setPointData(address verifier, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.Point memory weight)
    {
        weight = IRLPVerifier(verifier).setPointData(gauge, epoch, proof);
    }
}
