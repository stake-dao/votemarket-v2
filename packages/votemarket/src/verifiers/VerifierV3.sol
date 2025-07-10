// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

///  Project Interfaces & Libraries
import "src/verifiers/RLPDecoderV2.sol";

/// @title Verifier
/// @notice A contract for verifying and extracting data from block headers and proofs
/// @dev This contract uses RLP decoding and interacts with an Oracle contract
contract VerifierV3 is RLPDecoderV2 {
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
    event DebugBytes32(bytes32 data);
    event DebugString(string data);
    event DebugUint256(uint256 data);

    /// @notice Constructor to initialize the Verifier contract
    /// @param _oracle Address of the Oracle contract
    /// @param _gaugeController Address of the Gauge Controller
    /// @param _lastVoteMappingSlot Storage slot for last vote mapping
    /// @param _userSlopeMappingSlot Storage slot for user slope mapping
    /// @param _weightMappingSlot Storage slot for weight mapping
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

    /// @notice Sets block data and registers the block header
    /// @param blockHeader The block header data
    /// @param proof The proof for block header verification
    /// @return stateRootHash The state root hash of the registered block
    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32 stateRootHash) {
        StateProofVerifier.BlockHeader memory blockHeader_ = StateProofVerifier.parseBlockHeader(blockHeader);
        if (blockHeader_.number == 0) revert NO_BLOCK_NUMBER();

        // 1. Calculate the epoch based on the block timestamp
        uint256 epoch = blockHeader_.timestamp / 1 weeks * 1 weeks;
        // 2. Retrieve the epoch block header from the Oracle
        StateProofVerifier.BlockHeader memory epochBlockHeader = ORACLE.epochBlockNumber(epoch);

        //emit DebugBytes32(epochBlockHeader.hash);
        //emit DebugBytes32(blockHeader_.hash); // => wrong

        if (blockHeader_.hash != epochBlockHeader.hash) revert INVALID_BLOCK_HASH();
        if (blockHeader_.number != epochBlockHeader.number) revert INVALID_BLOCK_NUMBER();

        if (epochBlockHeader.stateRootHash != bytes32(0)) revert ALREADY_REGISTERED();

        stateRootHash = _registerBlockHeader(epoch, blockHeader_, proof.toRlpItem().toList());
    }

    /// @notice Sets account data for a specific gauge and epoch
    /// @param account The account address
    /// @param gauge The gauge address
    /// @param epoch The epoch number
    /// @param proof The proof for account data verification
    /// @return userSlope The extracted user slope data
    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.VotedSlope memory userSlope)
    {
        userSlope = ORACLE.votedSlopeByEpoch(account, gauge, epoch);
        if (userSlope.lastUpdate != 0) revert ALREADY_REGISTERED();

        userSlope = _extractAccountData(account, gauge, epoch, proof);

        ORACLE.insertAddressEpochData(account, gauge, epoch, userSlope);
    }

    /// @notice Sets point data for a specific gauge and epoch
    /// @param gauge The gauge address
    /// @param epoch The epoch number
    /// @param proof The proof for point data verification
    /// @return weight The extracted weight data
    function setPointData(address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IOracle.Point memory weight)
    {
        weight = ORACLE.pointByEpoch(gauge, epoch);
        if (weight.lastUpdate != 0) revert ALREADY_REGISTERED();

        weight = _extractPointData(gauge, epoch, proof);
        ORACLE.insertPoint(gauge, epoch, weight);
    }

    /// @notice Extracts account data from the provided proof
    /// @param account The account address
    /// @param gauge The gauge address
    /// @param epoch The epoch number
    /// @param proof The proof for account data extraction
    /// @return userSlope The extracted user slope data
    function _extractAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        internal
        
        returns (IOracle.VotedSlope memory userSlope)
    {
        // 1. Retrieve the registered block header for the given epoch
        StateProofVerifier.BlockHeader memory registered_block_header = ORACLE.epochBlockNumber(epoch);
        // 2. Get the state root hash from the block header
        bytes32 stateRootHash = registered_block_header.stateRootHash;
        if (stateRootHash == bytes32(0)) revert INVALID_HASH();

        // 3. Convert the proof to RLP items
        RLPReader.RLPItem[] memory proofs = proof.toRlpItem().toList();

        if (proofs.length != 2) revert INVALID_PROOF_LENGTH();

        // 4. Extract the last vote data
        emit DebugBytes32(bytes32(0));

        // 5. Extract the user slope data
        emit DebugBytes32(bytes32(0));
        userSlope = _extractUserSlope({
            account: account,
            gauge: gauge,
            stateRootHash: stateRootHash,
            proofSlope: proofs[1].toList()
        });

        userSlope.lastVote = 0;
        userSlope.lastUpdate = block.timestamp;
    }

    /// @notice Extracts point data from the provided proof
    /// @param gauge The gauge address
    /// @param epoch The epoch number
    /// @param proof The proof for point data extraction
    /// @return weight The extracted weight data
    function _extractPointData(address gauge, uint256 epoch, bytes calldata proof)
        internal
        view
        returns (IOracle.Point memory weight)
    {
        // 1. Retrieve the registered block header for the given epoch
        StateProofVerifier.BlockHeader memory registered_block_header = ORACLE.epochBlockNumber(epoch);
        // 2. Get the state root hash from the block header
        bytes32 stateRootHash = registered_block_header.stateRootHash;
        if (stateRootHash == bytes32(0)) revert INVALID_HASH();
        
        // 3. Convert the proof to RLP items
        RLPReader.RLPItem[] memory proofs = proof.toRlpItem().toList();

        if (proofs.length != 1) revert INVALID_PROOF_LENGTH();

        // 4. Extract the weight data
        weight = 
            _extractWeight({gauge: gauge, epoch: epoch, stateRootHash: stateRootHash, proofBias: proofs[0].toList()});

        weight.lastUpdate = block.timestamp;
    }

    /// @notice Registers a block header for a specific epoch
    /// @param epoch The epoch number
    /// @param block_header The block header data
    /// @param proof The proof for block header registration
    /// @return stateRootHash The state root hash of the registered block
    function _registerBlockHeader(
        uint256 epoch,
        StateProofVerifier.BlockHeader memory block_header,
        RLPReader.RLPItem[] memory proof
    ) internal returns (bytes32 stateRootHash) {
        // 1. Extract the gauge controller account from the proof
        StateProofVerifier.Account memory gauge_controller_account =
            StateProofVerifier.extractAccountFromProof(SOURCE_GAUGE_CONTROLLER_HASH, block_header.stateRootHash, proof);
        if (!gauge_controller_account.exists) revert GAUGE_CONTROLLER_NOT_FOUND();

        // 2. Update the state root hash of the block header
        block_header.stateRootHash = gauge_controller_account.storageRoot;
        // 3. Insert the block number into the Oracle
        ORACLE.insertBlockNumber(epoch, block_header);
        return block_header.stateRootHash;
    }

    /// @notice Extracts weight data from the proof
    /// @param gauge The gauge address
    /// @param epoch The epoch number
    /// @param stateRootHash The state root hash
    /// @param proofBias The proof for bias extraction
    /// @return weight The extracted weight data
    function _extractWeight(address gauge, uint256 epoch, bytes32 stateRootHash, RLPReader.RLPItem[] memory proofBias)
        internal
        view
        returns (IOracle.Point memory weight)
    {
        uint256 structSlot = uint256(keccak256(abi.encode( epoch, WEIGHT_MAPPING_SLOT)));
        uint256 poolVotesSlot = structSlot + 1;
        bytes32 slot = keccak256(abi.encode(uint256(keccak256(abi.encode( gauge, poolVotesSlot)))));

        weight.bias = StateProofVerifier.extractSlotValueFromProof(slot, stateRootHash, proofBias).value;
    }

    /// @notice Extracts user slope data from the proof
    /// @param account The account address
    /// @param gauge The gauge address
    /// @param stateRootHash The state root hash
    /// @param proofSlope The proof for slope extraction
    /// @return userSlope The extracted user slope data
    function _extractUserSlope(
        address account,
        address gauge,
        bytes32 stateRootHash,
        RLPReader.RLPItem[] memory proofSlope
    ) internal returns (IOracle.VotedSlope memory userSlope) {
        // 1. Extract the slope value from the nested mapping
        (uint128 bias, uint128 slope) = _extractUserPoolVoteBiasAndSlope(stateRootHash, account, gauge, proofSlope);
        emit DebugBytes32(bytes32(uint256(bias))); // => wrong
        userSlope.slope = bias;
        
        // 2. Extract the end value from the nested mapping
        userSlope.end = slope / bias;
    }

    function _extractUserPoolVoteBiasAndSlope(
        bytes32 stateRootHash,
        address user,
        address gauge,
        RLPReader.RLPItem[] memory proof
    ) internal view returns (uint128 bias, uint128 slope) {
        uint256 structSlot = uint256(keccak256(abi.encode(user, USER_SLOPE_MAPPING_SLOT)));
        bytes32 finalSlot = keccak256(abi.encode(gauge, structSlot + 1));
        bytes32 slotBiasSlope = keccak256(abi.encode(uint256(finalSlot) + 1));

        StateProofVerifier.SlotValue memory value =
            StateProofVerifier.extractSlotValueFromProof(slotBiasSlope, stateRootHash, proof);

        uint256 word = uint256(value.value);
        bias = uint128(word >> 128);
        slope = uint128(word & type(uint128).max);
    }
}

/*
struct UserPoolData {
        uint64 weight;
        VeBalance vote;
    }
    struct VeBalance {
    uint128 bias;
    uint128 slope;
}
*/