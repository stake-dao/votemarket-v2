// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "src/oracle/Oracle.sol";
import "src/verifiers/Verifier.sol";

interface IGaugeController {
    function last_user_vote(address, address) external view returns (uint256);
    function vote_user_slopes(address, address) external view returns (uint256, uint256);
}

contract ProofCorrectnessTest is Test {
    Oracle oracle;
    Verifier verifier;
    address internal constant GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    function setUp() public {
        vm.createSelectFork("mainnet", 20_449_552);

        oracle = new Oracle();
        verifier = new Verifier(address(oracle), GAUGE_CONTROLLER, 11, 9, 12);

        oracle.setAuthorizedDataProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(this));
        oracle.setAuthorizedBlockNumberProvider(address(verifier));
    }

    function testGetProofParams() public {
        address account = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
        address gauge = 0x16A3a047fC1D388d5846a73ACDb475b11228c299;
        uint256 epoch = block.timestamp / 1 weeks * 1 weeks;

        uint256 lastUserVote = IGaugeController(GAUGE_CONTROLLER).last_user_vote(account, gauge);
        (uint256 slope, uint256 power) = IGaugeController(GAUGE_CONTROLLER).vote_user_slopes(account, gauge);

        // Generate proofs for both gauge and account
        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory gaugeProofRlp) =
            generateAndEncodeProof(account, gauge, epoch, true);
        (,,, bytes memory accountProofRlp) = generateAndEncodeProof(account, gauge, epoch, false);

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

        IOracle.Point memory weight = verifier.setPointData(gauge, epoch, gaugeProofRlp);
        IOracle.VotedSlope memory userSlope = verifier.setAccountData(account, gauge, epoch, accountProofRlp);

        assertEq(userSlope.slope, slope);
        assertEq(userSlope.power, power);
        assertEq(userSlope.lastVote, lastUserVote);
    }

    function generateAndEncodeProof(address account, address gauge, uint256 epoch, bool isGaugeProof)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions =
            isGaugeProof ? generateGaugeProof(gauge, epoch) : generateAccountProof(account, gauge, epoch);

        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, block.number);
    }

    function generateGaugeProof(address gauge, uint256 epoch) internal pure returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](2);
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, gauge)), epoch)))));
        for (uint256 i = 0; i < 2; i++) {
            positions[i] = pointWeightsPosition + i;
        }
        return positions;
    }

    function generateAccountProof(address account, address gauge, uint256 epoch)
        internal
        pure
        returns (uint256[] memory)
    {
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
