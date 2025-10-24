// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/mocks/IVerifierBase.sol";
import "src/verifiers/Verifier.sol";
import "src/verifiers/VerifierV2.sol";
import "src/verifiers/VerifierPendle.sol";

import "src/verifiers/VerifierYB.sol";

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
                    new VerifierV2(
                        oracle, gaugeController, lastVoteMappingSlot, userSlopeMappingSlot, weightMappingSlot
                    )
                )
            );
        }

        return IVerifierBase(
            address(
                new Verifier(oracle, gaugeController, lastVoteMappingSlot, userSlopeMappingSlot, weightMappingSlot)
            )
        );
    }

    function createVerifierPendle(
        address oracle,
        address gaugeController,
        uint256 lastVoteMappingSlot,
        uint256 userSlopeMappingSlot,
        uint256 weightMappingSlot
    ) internal returns (IVerifierBase) {
        return IVerifierBase(
                address(
                    new VerifierPendle(
                        oracle, gaugeController, lastVoteMappingSlot, userSlopeMappingSlot, weightMappingSlot
                    )
                )
            );
    }

    function createVerifierYB(
        address oracle,
        address gaugeController,
        uint256 lastVoteMappingSlot,
        uint256 userSlopeMappingSlot,
        uint256 weightMappingSlot
    ) internal returns (IVerifierBase) {
        return IVerifierBase(
                address(
                    new VerifierYB(
                        oracle, gaugeController, lastVoteMappingSlot, userSlopeMappingSlot, weightMappingSlot
                    )
                )
            );
    }
}
