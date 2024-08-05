// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "src/verifiers/RLPDecoder.sol";

contract Verifier is RLPDecoder {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    address public immutable ORACLE;
    bytes32 public immutable SOURCE_GAUGE_CONTROLLER_HASH;

    uint256 public immutable WEIGHT_MAPPING_SLOT;
    uint256 public immutable LAST_VOTE_MAPPING_SLOT;
    uint256 public immutable USER_SLOPE_MAPPING_SLOT;

    error INVALID_HASH();
    error NO_BLOCK_NUMBER();
    error INVALID_HASH_MISMATCH();
    error INVALID_PROOF_LENGTH();
    error GAUGE_CONTROLLER_NOT_FOUND();

    constructor(
        address _oracle,
        address _gaugeController,
        uint256 _lastVoteMappingSlot,
        uint256 _userSlopeMappingSlot,
        uint256 _weightMappingSlot
    ) {
        ORACLE = _oracle;
        SOURCE_GAUGE_CONTROLLER_HASH = keccak256(abi.encodePacked(_gaugeController));

        USER_SLOPE_MAPPING_SLOT = _userSlopeMappingSlot;
        LAST_VOTE_MAPPING_SLOT = _lastVoteMappingSlot;
        WEIGHT_MAPPING_SLOT = _weightMappingSlot;
    }

    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32 stateRootHash) {
        StateProofVerifier.BlockHeader memory blockHeader = StateProofVerifier.parseBlockHeader(blockHeader);
        if (blockHeader.number == 0) revert NO_BLOCK_NUMBER();

        uint256 epoch = blockHeader.timestamp / 1 weeks * 1 weeks;
        StateProofVerifier.BlockHeader memory epochBlockHeader = IOracle(ORACLE).epochBlockNumber(epoch);

        if (epochBlockHeader.number == blockHeader.number && epochBlockHeader.stateRootHash == bytes32(0)) {
            stateRootHash =
                _registerBlockHeader({epoch: epoch, block_header: blockHeader, proof: proof.toRlpItem().toList()});

            return stateRootHash;
        }
    }

    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.Point memory weight, IOracle.VotedSlope memory userSlope, uint256 lastVote)
    {
        return _extractProofState(account, gauge, epoch, proof);
    }

    function _extractProofState(address account, address gauge, uint256 epoch, bytes calldata proof)
        internal
        view
        returns (IOracle.Point memory weight, IOracle.VotedSlope memory userSlope, uint256 lastVote)
    {
        StateProofVerifier.BlockHeader memory registered_block_header = IOracle(ORACLE).epochBlockNumber(epoch);
        bytes32 stateRootHash = registered_block_header.stateRootHash;
        if (stateRootHash == bytes32(0)) revert INVALID_HASH();

        RLPReader.RLPItem[] memory proofs = proof.toRlpItem().toList();
        if (proofs.length != 6) revert INVALID_PROOF_LENGTH();

        lastVote =
            _extractLastVote({account: account, gauge: gauge, stateRootHash: stateRootHash, proof: proofs[0].toList()});

        weight = _extractWeight({
            gauge: gauge,
            epoch: epoch,
            stateRootHash: stateRootHash,
            proofBias: proofs[1].toList(),
            proofSlope: proofs[2].toList()
        });

        userSlope = _extractUserSlope({
            account: account,
            gauge: gauge,
            stateRootHash: stateRootHash,
            proofSlope: proofs[3].toList(),
            proofPower: proofs[4].toList(),
            proofEnd: proofs[5].toList()
        });
    }

    function _registerBlockHeader(
        uint256 epoch,
        StateProofVerifier.BlockHeader memory block_header,
        RLPReader.RLPItem[] memory proof
    ) internal returns (bytes32 stateRootHash) {
        StateProofVerifier.Account memory gauge_controller_account =
            StateProofVerifier.extractAccountFromProof(SOURCE_GAUGE_CONTROLLER_HASH, block_header.stateRootHash, proof);
        if (!gauge_controller_account.exists) revert GAUGE_CONTROLLER_NOT_FOUND();

        block_header.stateRootHash = gauge_controller_account.storageRoot;
        IOracle(ORACLE).insertBlockNumber(epoch, block_header);
        return block_header.stateRootHash;
    }

    function _extractLastVote(address account, address gauge, bytes32 stateRootHash, RLPReader.RLPItem[] memory proof)
        internal
        view
        returns (uint256)
    {
        return extractMappingValue(LAST_VOTE_MAPPING_SLOT, account, gauge, stateRootHash, proof);
    }

    function _extractWeight(
        address gauge,
        uint256 epoch,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proofBias,
        RLPReader.RLPItem[] memory proofSlope
    ) internal view returns (IOracle.Point memory weight) {
        weight.bias =
            extractNestedMappingStructValue(WEIGHT_MAPPING_SLOT, gauge, bytes32(epoch), 0, stateRootHash, proofBias);
        weight.slope =
            extractNestedMappingStructValue(WEIGHT_MAPPING_SLOT, gauge, bytes32(epoch), 1, stateRootHash, proofSlope);
    }

    function _extractUserSlope(
        address account,
        address gauge,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proofSlope,
        RLPReader.RLPItem[] memory proofPower,
        RLPReader.RLPItem[] memory proofEnd
    ) internal view returns (IOracle.VotedSlope memory userSlope) {
        userSlope.slope =
            extractNestedMappingStructValue(USER_SLOPE_MAPPING_SLOT, account, gauge, 0, stateRootHash, proofSlope);
        userSlope.power =
            extractNestedMappingStructValue(USER_SLOPE_MAPPING_SLOT, account, gauge, 1, stateRootHash, proofPower);
        userSlope.end =
            extractNestedMappingStructValue(USER_SLOPE_MAPPING_SLOT, account, gauge, 2, stateRootHash, proofEnd);
    }
}
