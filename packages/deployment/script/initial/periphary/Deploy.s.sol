// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {L1Sender} from "@periphery/src/oracle/L1Sender.sol";
import {L1BlockOracleUpdater} from "@periphery/src/oracle/L1BlockOracleUpdater.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}

contract Deploy is Script {
    address public deployer = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    address public oracle = 0x66D1ad3500dd6ea1b9eA31313ceBae17cdE22437;
    address public laPoste = 0x345000000000FD99009B2BF0fb373Ca70f4C0047;
    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    L1Sender public l1Sender;
    L1BlockOracleUpdater public l1BlockOracleUpdater;

    string[] public chains = ["arbitrum", "optimism", "base", "polygon", "frax"];

    function run() public {
        vm.createSelectFork("optimism");

        bytes32 l1Salt = keccak256(abi.encode("l1BlockUpdater2"));
        address l1BlockUpdaterAddress = 0xeac7a85AEa083b3710eB477E60DeD9aA425b456E;

        console.log("l1BlockUpdaterAddress", l1BlockUpdaterAddress);

        bytes32 salt = keccak256(abi.encode("l1Sender2"));
        bytes memory initCode =
            abi.encodePacked(type(L1Sender).creationCode, abi.encode(l1BlockUpdaterAddress, laPoste));

        vm.createSelectFork("mainnet");

        vm.broadcast(deployer);
        l1Sender = L1Sender(ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode));

        address l1BlockOracle = address(0);
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));

            if (i == 1 || i == 4) {
                l1BlockOracle = 0x4200000000000000000000000000000000000015;
            }
            initCode = abi.encodePacked(
                type(L1BlockOracleUpdater).creationCode, abi.encode(l1BlockOracle, address(l1Sender), laPoste, oracle)
            );

            vm.broadcast(deployer);
            l1BlockOracleUpdater =
                L1BlockOracleUpdater(ICreate3Factory(CREATE3_FACTORY).deployCreate3(l1Salt, initCode));

            if (address(l1BlockOracleUpdater) != l1BlockUpdaterAddress) revert("Wtf");

            vm.broadcast(deployer);
            Oracle(oracle).setAuthorizedDataProvider(address(l1BlockOracleUpdater));
        }
    }
}
