// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";

import "src/oracle/Oracle.sol";
import "src/oracle/OracleLens.sol";
import "src/verifiers/Verifier.sol";
import "test/mocks/VerifierFactory.sol";
import "src/interfaces/IGaugeController.sol";
import "src/interfaces/IPendleGaugeController.sol";
import "src/interfaces/IVePendle.sol";

abstract contract ProofCorrectnessTest is Test, VerifierFactory {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;

    Oracle oracle;
    IVerifierBase public verifier;
    address public immutable GAUGE_CONTROLLER;
    bool public immutable isV2;

    address account;
    address gauge;
    address ve;
    uint256 blockNumber;

    uint256 lastUserVoteSlot;
    uint256 userSlopeSlot;
    uint256 weightSlot;

    constructor(
        address _gaugeController,
        address _account,
        address _gauge,
        uint256 _blockNumber,
        uint256 _lastUserVoteSlot,
        uint256 _userSlopeSlot,
        uint256 _weightSlot,
        bool _isV2,
        address _ve
    ) {
        GAUGE_CONTROLLER = _gaugeController;
        account = _account;
        gauge = _gauge;
        ve = _ve;
        blockNumber = _blockNumber;

        lastUserVoteSlot = _lastUserVoteSlot;
        userSlopeSlot = _userSlopeSlot;
        weightSlot = _weightSlot;
        isV2 = _isV2;
    }

    function setUp() public {
        vm.createSelectFork("mainnet", blockNumber);

        oracle = new Oracle(address(this));

        verifier = createVerifier(address(oracle), GAUGE_CONTROLLER, lastUserVoteSlot, userSlopeSlot, weightSlot, isV2);

        oracle.setAuthorizedDataProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(this));
        oracle.setAuthorizedBlockNumberProvider(address(verifier));
    }

    function testInitialSetup() public {
        assertEq(address(verifier.ORACLE()), address(oracle));
        assertEq(verifier.SOURCE_GAUGE_CONTROLLER_HASH(), keccak256(abi.encodePacked(GAUGE_CONTROLLER)));

        assertEq(oracle.authorizedDataProviders(address(verifier)), true);
        assertEq(oracle.authorizedBlockNumberProviders(address(this)), true);
        assertEq(oracle.authorizedBlockNumberProviders(address(verifier)), true);

        oracle.revokeAuthorizedDataProvider(address(verifier));
        oracle.revokeAuthorizedBlockNumberProvider(address(this));
        oracle.revokeAuthorizedBlockNumberProvider(address(verifier));

        assertEq(oracle.authorizedDataProviders(address(verifier)), false);
        assertEq(oracle.authorizedBlockNumberProviders(address(this)), false);
        assertEq(oracle.authorizedBlockNumberProviders(address(verifier)), false);

        Verifier newVerifier =
            new Verifier(address(oracle), GAUGE_CONTROLLER, lastUserVoteSlot, userSlopeSlot, weightSlot);
        assertEq(address(newVerifier.ORACLE()), address(oracle));
        assertEq(newVerifier.SOURCE_GAUGE_CONTROLLER_HASH(), keccak256(abi.encodePacked(GAUGE_CONTROLLER)));
        assertEq(newVerifier.WEIGHT_MAPPING_SLOT(), weightSlot);
        assertEq(newVerifier.LAST_VOTE_MAPPING_SLOT(), lastUserVoteSlot);
        assertEq(newVerifier.USER_SLOPE_MAPPING_SLOT(), userSlopeSlot);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Oracle.AUTH_GOVERNANCE_ONLY.selector);
        oracle.transferGovernance(address(0));

        vm.expectRevert(Oracle.ZERO_ADDRESS.selector);
        oracle.transferGovernance(address(0));

        oracle.transferGovernance(address(0xBEEF));

        vm.expectRevert(Oracle.AUTH_GOVERNANCE_ONLY.selector);
        oracle.acceptGovernance();

        assertEq(oracle.governance(), address(this));
        assertEq(oracle.futureGovernance(), address(0xBEEF));

        vm.prank(address(0xBEEF));
        oracle.acceptGovernance();

        assertEq(oracle.governance(), address(0xBEEF));
        assertEq(oracle.futureGovernance(), address(0));
    }

    function isPendle() public returns(bool) {
        return GAUGE_CONTROLLER == address(0x44087E105137a5095c008AaB6a6530182821F2F0);
    }

    function testGetProofParams() public {
        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;
        uint256 lastUserVote = block.timestamp;
        uint256 slope = 0;
        uint256 bias_ = 0;
        uint256 end = 0;
        address owner;

        if(isPendle()) {
            owner = IPendleGaugeController(GAUGE_CONTROLLER).owner();
            UserPoolData memory userPoolData = IPendleGaugeController(GAUGE_CONTROLLER).getUserPoolVote(account, gauge);
            slope = userPoolData.vote.slope;
            (bias_) = IPendleGaugeController(GAUGE_CONTROLLER).getPoolTotalVoteAt(gauge, uint128(epoch));
            (end,) = IVePendle(ve).positionData(account);
        } else {
            lastUserVote = IGaugeController(GAUGE_CONTROLLER).last_user_vote(account, gauge);
            (slope,, end) = IGaugeController(GAUGE_CONTROLLER).vote_user_slopes(account, gauge);
            (bias_,) = IGaugeController(GAUGE_CONTROLLER).points_weight(gauge, epoch);
        }

        console.logAddress(owner);

        // Generate proofs for both gauge and account
        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory storageProofRlp) =
            generateAndEncodeProofPendleOwner(account, gauge, epoch, true);

        /*
        console.logBytes32(blockHash);
        console.log("\n");
        console.logBytes(blockHeaderRlp);
        
        console.log("\n");
        console.logBytes(controllerProof);
        console.log("\n");
        console.logBytes(storageProofRlp);
        */

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: blockHash,
                stateRootHash: bytes32(0),
                number: block.number,
                timestamp: block.timestamp
            })
        );

        verifier.setBlockData(blockHeaderRlp, controllerProof);

        /********************* */

        // 2. Get the state root hash from the block header
        bytes32 stateRootHash = verifier.ORACLE().epochBlockNumber(epoch).stateRootHash;
        if (stateRootHash == bytes32(0)) revert VerifierV2.INVALID_HASH();

        RLPReader.RLPItem[] memory _proofs = storageProofRlp.toRlpItem().toList();  
        if (_proofs.length != 1) revert VerifierV2.INVALID_PROOF_LENGTH();
        
        address newOwner = extractOwner(stateRootHash, _proofs[0].toList());
        console.log("titi");
        console.log(newOwner);
        //assertEq(newOwner, owner);

        /********************* */

        /*IOracle.Point memory weight = verifier.setPointData(gauge, epoch, storageProofRlp);

        (,,, storageProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);

        console.logBytes(storageProofRlp);

        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, storageProofRlp);

        assertEq(userSlope.slope, slope);
        assertEq(userSlope.end, end);
        assertEq(userSlope.lastVote, lastUserVote);
        assertEq(weight.bias, bias_);*/
    }

    function testLens() public {
        OracleLens oracleLens = new OracleLens(address(oracle));
        assertEq(oracleLens.oracle(), address(oracle));

        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;

        // Generate proofs for both gauge and account
        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory storageProofRlp) =
            generateAndEncodeProof(account, gauge, epoch, true);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: blockHash,
                stateRootHash: bytes32(0),
                number: block.number,
                timestamp: block.timestamp
            })
        );
        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.getAccountVotes(account, gauge, epoch);

        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.getTotalVotes(gauge, epoch);

        vm.expectRevert(OracleLens.STATE_NOT_UPDATED.selector);
        oracleLens.isVoteValid(account, gauge, epoch);

        verifier.setBlockData(blockHeaderRlp, controllerProof);

        IOracle.Point memory weight = verifier.setPointData(gauge, epoch, storageProofRlp);
        (,,, storageProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);
        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, storageProofRlp);

        uint256 totalVotes = oracleLens.getTotalVotes(gauge, epoch);
        uint256 accountVotes = oracleLens.getAccountVotes(account, gauge, epoch);

        assertEq(totalVotes, weight.bias);
        if (epoch >= userSlope.end) {
            assertEq(totalVotes, 0);
        } else {
            assertEq(accountVotes, userSlope.slope * (userSlope.end - epoch));
        }

        if (userSlope.slope > 0 && epoch <= userSlope.end && epoch > userSlope.lastVote) {
            assertTrue(oracleLens.isVoteValid(account, gauge, epoch));
        } else {
            assertFalse(oracleLens.isVoteValid(account, gauge, epoch));
        }
    }

    function extractOwner(bytes32 stateRootHash, RLPReader.RLPItem[] memory proof) internal pure returns (address) {
        bytes32 slot = keccak256(abi.encodePacked(uint256(0)));
        StateProofVerifier.SlotValue memory slotValue = StateProofVerifier.extractSlotValueFromProof(slot, stateRootHash, proof);
        return address(uint160(slotValue.value));    
    }

    function generateAndEncodeProofPendleOwner(address account, address gauge, uint256 epoch, bool isGaugeProof)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions = new uint256[](1);
        positions[0] = 0;
        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, block.number);
    }

    function generateAndEncodeProof(address account, address gauge, uint256 epoch, bool isGaugeProof)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions;

        if(isPendle()) {
            positions = isGaugeProof ? generateGaugeProofPendle(gauge, uint128(epoch)) : generateAccountProofPendle(account, gauge);
        } else {
           // positions = isGaugeProof ? generateGaugeProof(gauge, epoch) : generateAccountProof(account, gauge);
        }

        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, block.number);
    }

    function generateGaugeProofPendle(address gauge, uint128 epoch) internal view returns (uint256[] memory) {
        uint256 structSlot = uint256(keccak256(abi.encode(weightSlot, gauge)));
        uint256 poolVotesSlot = structSlot + 1;
        uint256 finalSlot = uint256(keccak256(abi.encode(poolVotesSlot, epoch)));

        console.log("Slot in proof:");
        console.logBytes32(bytes32(finalSlot));

        uint256[] memory positions = new uint256[](1);
        positions[0] = uint256(finalSlot);
        return positions;
    }

    function generateGaugeProof(address gauge, uint256 epoch) internal view returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](1);

        uint256 pointWeightsPosition;
        if (isV2) {
            pointWeightsPosition = uint256(keccak256(abi.encode(keccak256(abi.encode(weightSlot, gauge)), epoch)));
        } else {
            pointWeightsPosition =
                uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(weightSlot, gauge)), epoch)))));
        }
        positions[0] = pointWeightsPosition;
        return positions;
    }
    //0x42df32c694c6a6ac3ff9fe06f7a382f3d284b86ead9ec6f21c99be18e6d63f58

    function generateAccountProofPendle(address account, address gauge) internal view returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](3);
        positions[0] = uint128(uint256(keccak256(abi.encode(keccak256(abi.encode(lastUserVoteSlot, account)), gauge))));

        uint128 voteUserSlopePosition;
        if (isV2) {
            voteUserSlopePosition = uint128(uint256(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge))));
        } else {
            voteUserSlopePosition = uint128(uint256(
                keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge))))
            ));
        }
        positions[1] = voteUserSlopePosition;
        positions[2] = voteUserSlopePosition + 2;

        return positions;
    }

    function generateAccountProof(address account, address gauge) internal view returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](3);
        positions[0] = uint256(keccak256(abi.encode(keccak256(abi.encode(lastUserVoteSlot, account)), gauge)));

        uint256 voteUserSlopePosition;
        if (isV2) {
            voteUserSlopePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge)));
        } else {
            voteUserSlopePosition = uint256(
                keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(userSlopeSlot, account)), gauge))))
            );
        }
        positions[1] = voteUserSlopePosition;
        positions[2] = voteUserSlopePosition + 2;

        return positions;
    }

    function getRLPEncodedProofs(
        string memory chain,
        address _account,
        uint256[] memory _positions,
        uint256 _blockNumber
    )
        internal
        returns (
            bytes32 _block_hash,
            bytes memory _block_header_rlp,
            bytes memory _account_proof,
            bytes memory _proof_rlp
        )
    {
        string[] memory inputs = new string[](5 + _positions.length);
        inputs[0] = "python3";
        inputs[1] = "test/python/generate_proof.py";
        inputs[2] = chain;
        inputs[3] = vm.toString(_account);
        inputs[4] = vm.toString(_blockNumber);
        for (uint128 i = 0; i < _positions.length; i++) {
            inputs[5 + i] = vm.toString(_positions[i]);
        }
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }
}
