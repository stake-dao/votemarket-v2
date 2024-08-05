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

        (uint256[6] memory _positions, uint256 _blockNumber) = generateEthProofParams(account, gauge, epoch);

        bytes32 _block_hash;
        bytes memory _block_header_rlp;
        bytes memory _account_proof;
        bytes memory _proof_rlp;

        (_block_hash, _block_header_rlp, _account_proof, _proof_rlp) =
            getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, _positions, _blockNumber);

        /// Simulate a block number insertion.
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: _block_hash,
                stateRootHash: bytes32(0),
                number: block.number,
                timestamp: block.timestamp
            })
        );

        verifier.setBlockData(_block_header_rlp, _account_proof);

        (, IOracle.VotedSlope memory userSlope, uint256 lastVote) =
            verifier.setAccountData(account, gauge, epoch, _proof_rlp);

        assertEq(lastUserVote, lastVote);
        assertEq(userSlope.slope, slope);
        assertEq(userSlope.power, power);
    }

    function getRLPEncodedProofs(
        string memory rpcUrl,
        address _account,
        uint256[6] memory _positions,
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
        string[] memory inputs = new string[](11);
        inputs[0] = "python3";
        inputs[1] = "test/python/generate_proof.py";
        inputs[2] = rpcUrl;
        inputs[3] = vm.toString(_account);
        for (uint256 i = 4; i < 10; i++) {
            inputs[i] = vm.toString(_positions[i - 4]);
        }
        inputs[10] = vm.toString(_blockNumber);
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }

    function generateEthProofParams(address account, address gauge, uint256 epoch)
        internal
        view
        returns (uint256[6] memory _positions, uint256)
    {
        uint256 lastUserVotePosition = uint256(keccak256(abi.encode(keccak256(abi.encode(11, account)), gauge)));
        _positions[0] = lastUserVotePosition;
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, gauge)), epoch)))));
        uint256 i;
        for (i = 0; i < 2; i++) {
            _positions[1 + i] = pointWeightsPosition + i;
        }

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, account)), gauge)))));
        for (i = 0; i < 3; i++) {
            _positions[3 + i] = voteUserSlopePosition + i;
        }
        return (_positions, block.number);
    }
}
