// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {VerifierYB} from "@votemarket/src/verifiers/VerifierYB.sol";
import {YbOracleLens} from "@votemarket/src/oracle/YbOracleLens.sol";

import {Votemarket} from "@votemarket/src/Votemarket.sol";

import {L1Sender} from "@periphery/src/oracle/L1Sender.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt) external view returns (address);
}

abstract contract BaseYB is Script {
    address public deployer = 0x428419Ad92317B09FE00675F181ac09c87D16450;
    address public governance = 0x428419Ad92317B09FE00675F181ac09c87D16450;
    address public allMight = 0x0000000a3Fc396B89e4c11841B39D9dff85a5D05;
    address public executor = 0x90569D8A1cF801709577B24dA526118f0C83Fc75;
    address public remote = 0x53aD4Cd1F1e52DD02aa9FC4A8250A1b74F351CA2;
    address public blockNumberProvider = 0xaE74643A86ca9544a41c266BC5BF2d26479f64E7;

    Oracle public oracle;
    VerifierYB public verifier;
    YbOracleLens public oracleLens;

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
    ) internal {
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));
            vm.startBroadcast(deployer);

            bytes32 salt = bytes32(0x9798502ba35ab64b3562abc509befb7eb178d4df0033a58e93d4505101a4684b);

            bytes memory initCode = abi.encodePacked(type(Oracle).creationCode, abi.encode(deployer));

            address oracleAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracle = Oracle(payable(oracleAddress));

            // Remove before real deployement
            /*oracle.setAuthorizedBlockNumberProvider(deployer);
            oracle.setAuthorizedDataProvider(deployer);
            oracle.setAuthorizedBlockNumberProvider(allMight);
            oracle.setAuthorizedDataProvider(allMight);
            oracle.setAuthorizedBlockNumberProvider(executor);
            oracle.setAuthorizedDataProvider(executor);
            */

            salt = bytes32(0x9798502ba35ab64b3562abc509befb7eb178d4df008b5b333b79b3050215ac73);

            initCode = abi.encodePacked(
                type(VerifierYB).creationCode,
                abi.encode(address(oracle), gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
            );

            address verifierAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            verifier = VerifierYB(payable(verifierAddress));

            salt = bytes32(0x9798502ba35ab64b3562abc509befb7eb178d4df00c2186d2e59f6ab0143f49a);

            initCode = abi.encodePacked(type(YbOracleLens).creationCode, abi.encode(address(oracle)));
            address oracleLensAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            oracleLens = YbOracleLens(payable(oracleLensAddress));

            salt = bytes32(0x9798502ba35ab64b3562abc509befb7eb178d4df0022fa0a210d8ba4034ba371);

            initCode = abi.encodePacked(
                type(Votemarket).creationCode,
                abi.encode(governance, address(oracleLensAddress), governance, epochLength, minPeriods)
            );

            address votemarketAddress = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);
            votemarket = Votemarket(payable(votemarketAddress));

            oracle.setAuthorizedDataProvider(address(verifier));
            oracle.transferGovernance(governance);
            oracle.setAuthorizedBlockNumberProvider(address(verifier));
            oracle.setAuthorizedBlockNumberProvider(blockNumberProvider);

            votemarket.setRemote(remote);

            vm.stopBroadcast();
        }
    }
}