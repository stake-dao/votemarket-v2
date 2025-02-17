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
    address public deployer = 0x606A503e5178908F10597894B35b2Be8685EAB90;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;
    address public feeCollector = 0x5DA07af8913A4EAf09E5F569c20138b658906c17;

    Votemarket public votemarket;

    string[] public chains = ["arbitrum", "optimism", "base", "polygon"];

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function run(uint8 minPeriods, uint256 epochLength, address oracleLensAddress) public {
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));
            vm.startBroadcast(deployer);

            bytes32 salt = keccak256(abi.encodePacked("curve", "votemarket"));
            /// bytes32 salt = keccak256(abi.encodePacked("balancer", "votemarket"));
            /// bytes32 salt = keccak256(abi.encodePacked("fxn", "votemarket"));

            bytes memory initCode = abi.encodePacked(
                type(Votemarket).creationCode,
                abi.encode(deployer, address(oracleLensAddress), feeCollector, epochLength, minPeriods)
            );

            address votemarketAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            votemarket = Votemarket(payable(votemarketAddress));

            vm.stopBroadcast();
        }
    }
}
