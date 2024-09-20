// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "src/VMMulticall.sol";
import {Oracle} from "@votemarket/oracle/Oracle.sol";
import {Verifier} from "@votemarket/verifiers/Verifier.sol";

contract DebugTest is Test { 
    Oracle oracle;
    Verifier verifier;
    VMMulticall multicaller;

    address GAUGE = 0xF1bb643F953836725c6E48BdD6f1816f871d3E07;
    uint256 EPOCH = 1723075200;
    address internal constant GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);
    
    function setUp() public {
        vm.createSelectFork("mainnet");
        oracle = new Oracle(address(this));
        verifier = new Verifier(address(oracle), GAUGE_CONTROLLER, 11, 9, 12);
        multicaller = new VMMulticall();

        oracle.setAuthorizedDataProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(this));
        oracle.setAuthorizedBlockNumberProvider(address(verifier));
    }

    function testProof() public {
        uint256[] memory proofs = generateGaugeProof(GAUGE, EPOCH);

        console.log(GAUGE);
        console.log(EPOCH);

        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory controllerProof, bytes memory storageProofRlp) =
            generateAndEncodeProof(address(this), GAUGE, EPOCH, true, 20481142);

        console.logBytes32(blockHash);
        console.logBytes(blockHeaderRlp);
        console.logBytes(controllerProof);
        console.logBytes(storageProofRlp);
        // Simulate a block number insertion
        oracle.insertBlockNumber(
            EPOCH,
            StateProofVerifier.BlockHeader({
                hash: 0x90e5ffa5dc151f4c44cfabc99658262387aebafb6f1de362e8c12b00459ad45f,
                stateRootHash: bytes32(0),
                number: 20481142,
                timestamp: 1723087259
            })
        );

        //verifier.setBlockData(blockHeaderRlp, controllerProof);
        //verifier.setPointData(GAUGE, EPOCH, storageProofRlp);
        bytes[] memory data = new bytes[](6);
        data[0] = abi.encodeWithSignature(
            "setBlockData(address,bytes,bytes)", address(verifier), blockHeaderRlp, controllerProof
        );
        data[1] = abi.encodeWithSignature(
            "setPointData(address,address,uint256,bytes)", address(verifier), GAUGE, EPOCH, storageProofRlp
        );

        (blockHash, blockHeaderRlp, controllerProof, storageProofRlp) =
            generateAndEncodeProof(address(this), GAUGE, EPOCH + 1 weeks, true, 20531310);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            EPOCH + 1 weeks,
            StateProofVerifier.BlockHeader({
                hash: 0x5ce0fbcbe0e3cf291056b6af2fc2412eb59f4929d47f5827c0ab337039856540,
                stateRootHash: bytes32(0),
                number: 20531310,
                timestamp: 1723692083
            })
        );

        // verifier.setBlockData(blockHeaderRlp, controllerProof);
        // verifier.setPointData(GAUGE, EPOCH + 1 weeks, storageProofRlp);
        data[2] = abi.encodeWithSignature(
            "setBlockData(address,bytes,bytes)", address(verifier), blockHeaderRlp, controllerProof
        );
        data[3] = abi.encodeWithSignature(
            "setPointData(address,address,uint256,bytes)", address(verifier), GAUGE, EPOCH+ 1 weeks, storageProofRlp
        );

        (blockHash, blockHeaderRlp, controllerProof, storageProofRlp) =
            generateAndEncodeProof(address(this), GAUGE, EPOCH + 2 weeks, true, 20581430);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            EPOCH + 2 weeks,
            StateProofVerifier.BlockHeader({
                hash: 0x567b29d08a94a593ac50c119d8d82b4450cb0439b863e5ac04733a368233a113,
                stateRootHash: bytes32(0),
                number: 20581430,
                timestamp: 1724296895
            })
        );

        //verifier.setBlockData(blockHeaderRlp, controllerProof);
        //verifier.setPointData(GAUGE, EPOCH + 2 weeks, storageProofRlp);

        data[4] = abi.encodeWithSignature(
            "setBlockData(address,bytes,bytes)", address(verifier), blockHeaderRlp, controllerProof
        );
        data[5] = abi.encodeWithSignature(
            "setPointData(address,address,uint256,bytes)", address(verifier), GAUGE, EPOCH+ 2 weeks, storageProofRlp
        );
        //console.logBytes(abi.encodeWithSignature("multicall(bytes[])",data));
        multicaller.multicall(data);

    }

    function generateAndEncodeProof(address account, address gauge, uint256 epoch, bool isGaugeProof, uint256 blockNumber)
        internal
        returns (bytes32, bytes memory, bytes memory, bytes memory)
    {
        uint256[] memory positions =
            isGaugeProof ? generateGaugeProof(gauge, epoch) : generateAccountProof(account, gauge);

        return getRLPEncodedProofs("mainnet", GAUGE_CONTROLLER, positions, blockNumber);
    }

    function generateGaugeProof(address gauge, uint256 epoch) internal pure returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](1);
        uint256 pointWeightsPosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(12, gauge)), epoch)))));
        positions[0] = pointWeightsPosition;
        return positions;
    }
    function generateAccountProof(address account, address gauge) internal pure returns (uint256[] memory) {
        uint256[] memory positions = new uint256[](3);
        positions[0] = uint256(keccak256(abi.encode(keccak256(abi.encode(11, account)), gauge)));

        uint256 voteUserSlopePosition =
            uint256(keccak256(abi.encode(keccak256(abi.encode(keccak256(abi.encode(9, account)), gauge)))));
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
        for (uint256 i = 0; i < _positions.length; i++) {
            inputs[5 + i] = vm.toString(_positions[i]);
        }
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }
}