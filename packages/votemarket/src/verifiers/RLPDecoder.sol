// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "@utils/StateProofVerifier.sol";
import "@solady/src/utils/LibString.sol";

/// Project Interfaces & Libraries
import "src/interfaces/IOracle.sol";

abstract contract RLPDecoder {
    function extractMappingValue(
        uint256 slotNumber,
        address param1,
        address param2,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proof
    ) internal pure returns (uint256) {
        bytes32 slot =
            keccak256(abi.encode(uint256(keccak256(abi.encode(keccak256(abi.encode(slotNumber, param1)), param2)))));
        return StateProofVerifier.extractSlotValueFromProof(slot, stateRootHash, proof).value;
    }

    function extractNestedMappingStructValue(
        uint256 slotNumber,
        address param1,
        address param2,
        uint256 offset,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proof
    ) internal pure returns (uint256) {
        bytes32 slot = keccak256(
            abi.encode(
                uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(slotNumber, param1)), param2)))))
                    + offset
            )
        );
        return StateProofVerifier.extractSlotValueFromProof(slot, stateRootHash, proof).value;
    }

    function extractNestedMappingStructValue(
        uint256 slotNumber,
        address param1,
        bytes32 param2,
        uint256 offset,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proof
    ) internal pure returns (uint256) {
        bytes32 slot = keccak256(
            abi.encode(
                uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(slotNumber, param1)), param2)))))
                    + offset
            )
        );
        return StateProofVerifier.extractSlotValueFromProof(slot, stateRootHash, proof).value;
    }
}
