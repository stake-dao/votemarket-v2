// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@forge-std/src/mocks/MockERC20.sol";

import "src/bundler/Bundler.sol";

import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {Verifier} from "@votemarket/src/verifiers/Verifier.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {OracleLens} from "@votemarket/src/oracle/OracleLens.sol";

contract VMMulticallTest is Test {
    /// Curve Gauge Controller
    address public constant GAUGE_CONTROLLER = 0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB;

    address constant CRV_ACCOUNT = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
    address constant CRV_GAUGE = 0x16A3a047fC1D388d5846a73ACDb475b11228c299;
    uint256 constant CRV_BLOCK_NUMBER = 20_449_552;

    uint256 constant CRV_LAST_USER_VOTE_SLOT = 11;
    uint256 constant CRV_USER_SLOPE_SLOT = 9;
    uint256 constant CRV_WEIGHT_SLOT = 12;

    uint256 campaignId;

    Bundler multicaller;

    MockERC20 rewardToken;
    Votemarket votemarket;
    Verifier verifier;
    Oracle oracle;
    OracleLens oracleLens;

    function setUp() public {
        vm.createSelectFork("mainnet", CRV_BLOCK_NUMBER);

        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        multicaller = new Bundler();

        oracle = new Oracle(address(this));
        oracleLens = new OracleLens(address(oracle));

        verifier = new Verifier(
            address(oracle), GAUGE_CONTROLLER, CRV_LAST_USER_VOTE_SLOT, CRV_USER_SLOPE_SLOT, CRV_WEIGHT_SLOT
        );

        votemarket = new Votemarket({
            _governance: address(this),
            _oracle: address(oracleLens),
            _feeCollector: address(this),
            _epochLength: 1 weeks,
            _minimumPeriods: 2
        });

        oracle.setAuthorizedDataProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(verifier));
        oracle.setAuthorizedBlockNumberProvider(address(this));

        deal(address(rewardToken), address(this), 100_000e18);
        rewardToken.approve(address(votemarket), type(uint256).max);

        campaignId = votemarket.createCampaign({
            chainId: 1,
            gauge: CRV_GAUGE,
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 100_000e18,
            totalRewardAmount: 100_000e18,
            addresses: new address[](0),
            hook: address(0),
            isWhitelist: false
        });
    }

    function test_multicall() public {
        uint256 epoch = (block.timestamp) / 1 weeks * 1 weeks;

        (bytes32 blockHash, bytes memory blockHeaderRlp, bytes memory accountProof, bytes memory proofRlp) =
            generateAndEncodeProof(CRV_ACCOUNT, CRV_GAUGE, epoch, true);

        (,,, bytes memory userProofRlp) = generateAndEncodeProof(CRV_ACCOUNT, CRV_GAUGE, epoch, false);

        // Simulate a block number insertion
        oracle.insertBlockNumber(
            epoch,
            StateProofVerifier.BlockHeader({
                hash: blockHash,
                stateRootHash: bytes32(0),
                number: CRV_BLOCK_NUMBER,
                timestamp: block.timestamp
            })
        );

        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSignature(
            "setBlockData(address,bytes,bytes)", address(verifier), blockHeaderRlp, accountProof
        );
        data[1] = abi.encodeWithSignature(
            "setPointData(address,address,uint256,bytes)", address(verifier), CRV_GAUGE, epoch, proofRlp
        );
        data[2] = abi.encodeWithSignature(
            "setAccountData(address,address,address,uint256,bytes)",
            address(verifier),
            CRV_ACCOUNT,
            CRV_GAUGE,
            epoch,
            userProofRlp
        );
        data[3] = abi.encodeWithSignature(
            "claim(address,uint256,address,uint256,bytes)",
            address(votemarket),
            campaignId,
            CRV_ACCOUNT,
            epoch,
            new bytes(0)
        );

        vm.prank(CRV_ACCOUNT);

        /// We just want to check that the call go through. If it hits that revert, the call is good.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        multicaller.multicall(data);

        data[3] = abi.encodeWithSignature(
            "updateEpoch(address,uint256,uint256,bytes)", address(votemarket), campaignId, epoch, new bytes(0)
        );

        /// We just want to check that the call go through. If it hits that revert, the call is good.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        multicaller.multicall(data);
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
        inputs[1] = "../votemarket/test/python/generate_proof.py";
        inputs[2] = chain;
        inputs[3] = vm.toString(_account);
        inputs[4] = vm.toString(_blockNumber);
        for (uint256 i = 0; i < _positions.length; i++) {
            inputs[5 + i] = vm.toString(_positions[i]);
        }
        return abi.decode(vm.ffi(inputs), (bytes32, bytes, bytes, bytes));
    }
}
