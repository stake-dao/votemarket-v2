// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/verifiers/RLPDecoder.sol";

contract Verifier is RLPDecoder {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    IOracle public immutable ORACLE;
    bytes32 public immutable SOURCE_GAUGE_CONTROLLER_HASH;

    uint256 public immutable WEIGHT_MAPPING_SLOT;
    uint256 public immutable LAST_VOTE_MAPPING_SLOT;
    uint256 public immutable USER_SLOPE_MAPPING_SLOT;

    error INVALID_HASH();
    error NO_BLOCK_NUMBER();
    error ALREADY_REGISTERED();
    error INVALID_BLOCK_HASH();
    error INVALID_BLOCK_NUMBER();
    error INVALID_PROOF_LENGTH();
    error GAUGE_CONTROLLER_NOT_FOUND();

    constructor(
        address _oracle,
        address _gaugeController,
        uint256 _lastVoteMappingSlot,
        uint256 _userSlopeMappingSlot,
        uint256 _weightMappingSlot
    ) {
        ORACLE = IOracle(_oracle);
        SOURCE_GAUGE_CONTROLLER_HASH = keccak256(abi.encodePacked(_gaugeController));

        USER_SLOPE_MAPPING_SLOT = _userSlopeMappingSlot;
        LAST_VOTE_MAPPING_SLOT = _lastVoteMappingSlot;
        WEIGHT_MAPPING_SLOT = _weightMappingSlot;
    }

    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32 stateRootHash) {
        StateProofVerifier.BlockHeader memory blockHeader_ = StateProofVerifier.parseBlockHeader(blockHeader);
        if (blockHeader_.number == 0) revert NO_BLOCK_NUMBER();

        uint256 epoch = blockHeader_.timestamp / 1 weeks * 1 weeks;
        StateProofVerifier.BlockHeader memory epochBlockHeader = ORACLE.epochBlockNumber(epoch);

        if (blockHeader_.hash != epochBlockHeader.hash) revert INVALID_BLOCK_HASH();
        if (blockHeader_.number != epochBlockHeader.number) revert INVALID_BLOCK_NUMBER();

        if (epochBlockHeader.stateRootHash != bytes32(0)) revert ALREADY_REGISTERED();

        stateRootHash = _registerBlockHeader(epoch, blockHeader_, proof.toRlpItem().toList());

        return stateRootHash;
    }

    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.VotedSlope memory userSlope)
    {
        userSlope = ORACLE.votedSlopeByEpoch(account, gauge, epoch);
        if (userSlope.lastUpdate != 0) revert ALREADY_REGISTERED();

        userSlope = _extractAccountData(account, gauge, epoch, proof);
        ORACLE.insertAddressEpochData(account, gauge, epoch, userSlope);
        return userSlope;
    }

    function setPointData(address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.Point memory weight)
    {
        weight = ORACLE.pointByEpoch(gauge, epoch);
        if (weight.lastUpdate != 0) revert ALREADY_REGISTERED();

        weight = _extractPointData(gauge, epoch, proof);
        ORACLE.insertPoint(gauge, epoch, weight);
        return weight;
    }

    function _extractAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        internal
        view
        returns (IOracle.VotedSlope memory userSlope)
    {
        StateProofVerifier.BlockHeader memory registered_block_header = ORACLE.epochBlockNumber(epoch);
        bytes32 stateRootHash = registered_block_header.stateRootHash;
        if (stateRootHash == bytes32(0)) revert INVALID_HASH();

        RLPReader.RLPItem[] memory proofs = proof.toRlpItem().toList();

        if (proofs.length != 4) revert INVALID_PROOF_LENGTH();

        uint256 lastVote =
            _extractLastVote({account: account, gauge: gauge, stateRootHash: stateRootHash, proof: proofs[0].toList()});

        userSlope = _extractUserSlope({
            account: account,
            gauge: gauge,
            stateRootHash: stateRootHash,
            proofSlope: proofs[1].toList(),
            proofPower: proofs[2].toList(),
            proofEnd: proofs[3].toList()
        });

        userSlope.lastVote = lastVote;
        userSlope.lastUpdate = block.timestamp;
    }

    function _extractPointData(address gauge, uint256 epoch, bytes calldata proof)
        internal
        view
        returns (IOracle.Point memory weight)
    {
        StateProofVerifier.BlockHeader memory registered_block_header = ORACLE.epochBlockNumber(epoch);
        bytes32 stateRootHash = registered_block_header.stateRootHash;
        if (stateRootHash == bytes32(0)) revert INVALID_HASH();

        RLPReader.RLPItem[] memory proofs = proof.toRlpItem().toList();

        if (proofs.length != 2) revert INVALID_PROOF_LENGTH();

        weight = _extractWeight({
            gauge: gauge,
            epoch: epoch,
            stateRootHash: stateRootHash,
            proofBias: proofs[0].toList(),
            proofSlope: proofs[1].toList()
        });

        weight.lastUpdate = block.timestamp;
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
        ORACLE.insertBlockNumber(epoch, block_header);
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
