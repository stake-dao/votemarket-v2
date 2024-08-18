// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";

import "src/oracle/Oracle.sol";
import "src/oracle/OracleLens.sol";
import "src/verifiers/Verifier.sol";
import "src/interfaces/IGaugeController.sol";

abstract contract ProofCorrectnessTest is Test {
    Oracle oracle;
    Verifier verifier;
    address internal constant GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    address account;
    address gauge;
    uint256 blockNumber;

    uint256 lastUserVoteSlot;
    uint256 userSlopeSlot;
    uint256 weightSlot;

    constructor(
        address _account,
        address _gauge,
        uint256 _blockNumber,
        uint256 _lastUserVoteSlot,
        uint256 _userSlopeSlot,
        uint256 _weightSlot
    ) {
        account = _account;
        gauge = _gauge;
        blockNumber = _blockNumber;

        lastUserVoteSlot = _lastUserVoteSlot;
        userSlopeSlot = _userSlopeSlot;
        weightSlot = _weightSlot;
    }

    function setUp() public {
        vm.createSelectFork("mainnet", blockNumber);

        oracle = new Oracle(address(this));
        verifier = new Verifier(address(oracle), GAUGE_CONTROLLER, 11, 9, 12);

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

        Verifier newVerifier = new Verifier(address(oracle), GAUGE_CONTROLLER, 11, 9, 12);
        assertEq(address(newVerifier.ORACLE()), address(oracle));
        assertEq(newVerifier.SOURCE_GAUGE_CONTROLLER_HASH(), keccak256(abi.encodePacked(GAUGE_CONTROLLER)));
        assertEq(newVerifier.WEIGHT_MAPPING_SLOT(), 12);
        assertEq(newVerifier.LAST_VOTE_MAPPING_SLOT(), 11);
        assertEq(newVerifier.USER_SLOPE_MAPPING_SLOT(), 9);

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

    function testGetProofParams() public {
        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;

        uint256 lastUserVote = IGaugeController(GAUGE_CONTROLLER).last_user_vote(account, gauge);
        (uint256 slope, uint256 power) = IGaugeController(GAUGE_CONTROLLER).vote_user_slopes(account, gauge);
        (uint256 bias_, uint256 slope_) = IGaugeController(GAUGE_CONTROLLER).points_weight(gauge, epoch);

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

        verifier.setBlockData(blockHeaderRlp, controllerProof);
        IOracle.Point memory weight = verifier.setPointData(gauge, epoch, storageProofRlp);

        (,,, storageProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);
        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, storageProofRlp);

        assertEq(userSlope.slope, slope);
        assertEq(userSlope.power, power);
        assertEq(userSlope.lastVote, lastUserVote);
        assertEq(weight.bias, bias_);
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
        oracleLens.canClaim(account, gauge, epoch);

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
            assertTrue(oracleLens.canClaim(account, gauge, epoch));
        } else {
            assertFalse(oracleLens.canClaim(account, gauge, epoch));
        }
    }

    function generateAndEncodeProof(address account, address gauge, uint256 epoch, bool isGaugeProof)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions =
            isGaugeProof ? generateGaugeProof(gauge, epoch) : generateAccountProof(account, gauge);

        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, block.number);
    }

    function generateGaugeProof(address gauge, uint256 epoch) internal pure returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](1);
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, gauge)), epoch)))));
        positions[0] = pointWeightsPosition;
        return positions;
    }

    function generateAccountProof(address account, address gauge) internal pure returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](4);
        positions[0] = uint256(keccak256(abi.encode(keccak256(abi.encode(11, account)), gauge)));

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, account)), gauge)))));
        for (uint256 i = 0; i < 3; i++) {
            positions[1 + i] = voteUserSlopePosition + i;
        }
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
        for (uint256 i = 0; i < _positions.length; i++) {
            inputs[5 + i] = vm.toString(_positions[i]);
        }
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }
}
