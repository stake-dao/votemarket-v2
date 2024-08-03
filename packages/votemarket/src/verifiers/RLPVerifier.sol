// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@utils/StateProofVerifier.sol";
import "@solady/src/utils/LibString.sol";
import "src/interfaces/IOracle.sol";

contract RLPVerifier {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    address public immutable ORACLE;
    bytes32 public immutable SOURCE_GAUGE_CONTROLLER_HASH;

    error INVALID_HASH();
    error INVALID_HASH_MISMATCH();
    error INVALID_PROOF_LENGTH();
    error GAUGE_CONTROLLER_NOT_FOUND();

    constructor(address _oracle, address _gaugeController) {
        ORACLE = _oracle;
        SOURCE_GAUGE_CONTROLLER_HASH = keccak256(abi.encodePacked(_gaugeController));
    }

    function getProofState(address _user, address _gauge, bytes calldata _block_header_rlp, bytes calldata _proof_rlp)
        external
        view
        returns (
            IOracle.Point memory weight,
            IOracle.VotedSlope memory userSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {
        return _extractProofState(_user, _gauge, _block_header_rlp, _proof_rlp);
    }

    function _extractProofState(
        address _user,
        address _gauge,
        bytes calldata _block_header_rlp,
        bytes calldata _proof_rlp
    )
        internal
        view
        returns (
            IOracle.Point memory weight,
            IOracle.VotedSlope memory userSlope,
            uint256 lastVote,
            uint256 blockNumber,
            bytes32 stateRootHash
        )
    {
        StateProofVerifier.BlockHeader memory block_header = StateProofVerifier.parseBlockHeader(_block_header_rlp);
        blockNumber = block_header.number;

        if (block_header.hash == bytes32(0)) revert INVALID_HASH();

        RLPReader.RLPItem[] memory proofs = _proof_rlp.toRlpItem().toList();
        if (proofs.length < 7) revert INVALID_PROOF_LENGTH();

        stateRootHash = block_header.stateRootHash;
        StateProofVerifier.Account memory gauge_controller_account = StateProofVerifier.extractAccountFromProof(
            SOURCE_GAUGE_CONTROLLER_HASH, block_header.stateRootHash, proofs[0].toList()
        );
        console.log(gauge_controller_account.exists);
        if (!gauge_controller_account.exists) revert GAUGE_CONTROLLER_NOT_FOUND();

        stateRootHash = gauge_controller_account.storageRoot;

        unchecked {
            lastVote = extractMappingValue(11, _user, _gauge, stateRootHash, proofs[1].toList());

            userSlope.slope = extractNestedMappingStructValue(9, _user, _gauge, 0, stateRootHash, proofs[4].toList());
            userSlope.power = extractNestedMappingStructValue(9, _user, _gauge, 1, stateRootHash, proofs[5].toList());
            userSlope.end = extractNestedMappingStructValue(9, _user, _gauge, 2, stateRootHash, proofs[6].toList());

            if (weight.bias == 0) {
                uint256 time = (block_header.timestamp / 1 weeks) * 1 weeks;
                weight.bias =
                    extractNestedMappingStructValue(12, _gauge, bytes32(time), 0, stateRootHash, proofs[2].toList());
                weight.slope =
                    extractNestedMappingStructValue(12, _gauge, bytes32(time), 1, stateRootHash, proofs[3].toList());
            }
        }
    }

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
