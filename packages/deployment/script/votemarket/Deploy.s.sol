// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {Verifier} from "@votemarket/src/verifiers/Verifier.sol";
import {OracleLens} from "@votemarket/src/oracle/OracleLens.sol";

import {Votemarket} from "@votemarket/src/Votemarket.sol";

import {L1Sender} from "@periphery/src/oracle/L1Sender.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
}

contract Deploy is Script {
    address public deployer;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    Oracle public oracle;
    Verifier public verifier;
    OracleLens public oracleLens;

    Votemarket public votemarket;

    string[] public chains = ["arbitrum", "optimism", "base", "polygon"];

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);
    address public constant GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    function run() public {
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));
            vm.startBroadcast(deployer);

            bytes32 salt = keccak256(abi.encode("oracle"));

            bytes memory initCode = abi.encodePacked(type(Oracle).creationCode, abi.encode(deployer));
            address oracleAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracle = Oracle(payable(oracleAddress));

            salt = keccak256(abi.encode("verifier"));

            initCode =
                abi.encodePacked(type(Verifier).creationCode, abi.encode(address(oracle), GAUGE_CONTROLLER, 11, 9, 12));
            address verifierAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            verifier = Verifier(payable(verifierAddress));

            salt = keccak256(abi.encode("oracleLens"));

            initCode = abi.encodePacked(type(OracleLens).creationCode, abi.encode(address(oracle)));
            address oracleLensAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracleLens = OracleLens(payable(oracleLensAddress));

            salt = keccak256(abi.encode("votemarket"));

            initCode = abi.encodePacked(
                type(Votemarket).creationCode,
                abi.encode(governance, address(oracleLensAddress), governance, 1 weeks, 2)
            );
            address votemarketAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            votemarket = Votemarket(payable(votemarketAddress));

            oracle.setAuthorizedDataProvider(address(verifier));
            oracle.transferGovernance(governance);

            vm.stopBroadcast();
        }
    }
}