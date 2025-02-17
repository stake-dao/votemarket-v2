// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {VerifierV2} from "@votemarket/src/verifiers/VerifierV2.sol";
import {OracleLens} from "@votemarket/src/oracle/OracleLens.sol";

import {Votemarket} from "@votemarket/src/Votemarket.sol";

import {L1Sender} from "@periphery/src/oracle/L1Sender.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt) external view returns (address);
}

abstract contract Base is Script {
    address public deployer = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    Oracle public oracle;
    VerifierV2 public verifier;
    OracleLens public oracleLens;

    Votemarket public votemarket;

    string[] public chains = ["arbitrum", "optimism", "base", "polygon"];

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function run(
        address gaugeController,
        uint8 minPeriods,
        uint256 epochLength,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public {
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));
            vm.startBroadcast(deployer);

            bytes32 salt = bytes32(0x8898502ba35ab64b3562abc509befb7eb178d4df0033a58e93d4505101a4684b);

            bytes memory initCode = abi.encodePacked(type(Oracle).creationCode, abi.encode(deployer));

            address oracleAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracle = Oracle(payable(oracleAddress));

            salt = bytes32(0x8898502ba35ab64b3562abc509befb7eb178d4df008b5b333b79b3050215ac73);

            initCode = abi.encodePacked(
                type(VerifierV2).creationCode,
                abi.encode(address(oracle), gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
            );

            address verifierAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            verifier = VerifierV2(payable(verifierAddress));

            salt = bytes32(0x8898502ba35ab64b3562abc509befb7eb178d4df00c2186d2e59f6ab0143f49a);

            initCode = abi.encodePacked(type(OracleLens).creationCode, abi.encode(address(oracle)));
            address oracleLensAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracleLens = OracleLens(payable(oracleLensAddress));

            salt = bytes32(0x8898502ba35ab64b3562abc509befb7eb178d4df0022fa0a210d8ba4034ba371);

            initCode = abi.encodePacked(
                type(Votemarket).creationCode,
                abi.encode(governance, address(oracleLensAddress), governance, epochLength, minPeriods)
            );

            address votemarketAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            votemarket = Votemarket(payable(votemarketAddress));

            oracle.setAuthorizedDataProvider(address(verifier));
            oracle.transferGovernance(governance);

            vm.stopBroadcast();
        }
    }
}
