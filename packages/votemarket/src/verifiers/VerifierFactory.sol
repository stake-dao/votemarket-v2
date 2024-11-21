// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IVerifierBase.sol";
import "src/verifiers/Verifier.sol";
import "src/verifiers/Verifier_V2.sol";

abstract contract VerifierFactory {
    function createVerifier(
        address oracle,
        address gaugeController,
        uint256 lastVoteMappingSlot,
        uint256 userSlopeMappingSlot,
        uint256 weightMappingSlot,
        bool isV2
    ) internal returns (IVerifierBase) {
        if (isV2) {
            return IVerifierBase(
                address(
                    new Verifier_V2(
                        oracle,
                        gaugeController,
                        lastVoteMappingSlot,
                        userSlopeMappingSlot,
                        weightMappingSlot
                    )
                )
            );
        } else {
            return IVerifierBase(
                address(
                    new Verifier(
                        oracle,
                        gaugeController,
                        lastVoteMappingSlot,
                        userSlopeMappingSlot,
                        weightMappingSlot
                    )
                )
            );
        }
    }
}