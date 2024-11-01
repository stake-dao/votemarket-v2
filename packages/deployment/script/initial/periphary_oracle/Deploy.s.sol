// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {Bundler} from "@periphery/src/bundler/Bundler.sol";
import {L1Sender} from "@periphery/src/oracle/L1Sender.sol";
import {L1BlockOracleUpdater} from "@periphery/src/oracle/L1BlockOracleUpdater.sol";
import {CampaignRemoteManager} from "@periphery/src/remote/CampaignRemoteManager.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}

contract Deploy is Script {
    address public deployer = 0x606A503e5178908F10597894B35b2Be8685EAB90;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    address public oracle = 0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8;
    address public votemarket = 0x5e5C922a5Eeab508486eB906ebE7bDFFB05D81e5;

    address public laPoste = 0xF0000058000021003E4754dCA700C766DE7601C2;
    address public tokenFactory = 0x96006425Da428E45c282008b00004a00002B345e;

    address public old_L1BlockOracleUpdater = 0xb104D3A146F909D9D722005A5BDb17E570C88C6A;

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    L1Sender public l1Sender;
    L1BlockOracleUpdater public l1BlockOracleUpdater;

    string[] public chains = ["arbitrum", "optimism", "base", "polygon"];

    function run() public {
        vm.createSelectFork("optimism");

        bytes32 salt = bytes32(0x606a503e5178908f10597894b35b2be8685eab9000b35dad48ecf0ff03b2f4c4);
        bytes memory initCode = abi.encodePacked(type(L1Sender).creationCode, abi.encode(laPoste, deployer));

        vm.createSelectFork("mainnet");
        vm.broadcast(deployer);
        l1Sender = L1Sender(ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode));

        address l1BlockOracle = address(0);
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));

            if (i == 1) {
                l1BlockOracle = 0x4200000000000000000000000000000000000015;
            } else {
                l1BlockOracle = address(0);
            }

            salt = bytes32(0x606a503e5178908f10597894b35b2be8685eab900045239010c8fdff04afcecf);
            initCode = abi.encodePacked(
                type(L1BlockOracleUpdater).creationCode, abi.encode(l1BlockOracle, address(l1Sender), laPoste, oracle)
            );

            vm.broadcast(deployer);
            l1BlockOracleUpdater = L1BlockOracleUpdater(ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode));

            vm.broadcast(deployer);
            Oracle(oracle).setAuthorizedBlockNumberProvider(address(l1BlockOracleUpdater));

            vm.broadcast(deployer);
            Oracle(oracle).revokeAuthorizedBlockNumberProvider(old_L1BlockOracleUpdater);

            if (i == 1) {
                l1BlockOracleUpdater.updateL1BlockNumber();
            }
        }

        vm.selectFork(1);
        vm.broadcast(deployer);
        L1Sender(l1Sender).setL1BlockOracleUpdater(address(l1BlockOracleUpdater));
    }
}
