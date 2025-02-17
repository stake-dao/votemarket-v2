// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Bundler} from "@periphery/src/bundler/Bundler.sol";
import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {CampaignRemoteManager} from "@periphery/src/remote/CampaignRemoteManager.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}

contract Deploy is Script {
    address public deployer = 0x606A503e5178908F10597894B35b2Be8685EAB90;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;
    address public votemarket = 0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9;

    address public laPoste = 0xF0000058000021003E4754dCA700C766DE7601C2;
    address public tokenFactory = 0x96006425Da428E45c282008b00004a00002B345e;

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    CampaignRemoteManager public campaignRemoteManager;

    string[] public chains = ["mainnet", "arbitrum", "optimism", "base", "polygon"];

    function run() public {
        bytes32 campaignSalt = keccak256(abi.encodePacked("campaignRemoteManager"));
        bytes memory campaignInitCode =
            abi.encodePacked(type(CampaignRemoteManager).creationCode, abi.encode(laPoste, tokenFactory, deployer));

        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));

            vm.broadcast(deployer);
            campaignRemoteManager =
                CampaignRemoteManager(ICreate3Factory(CREATE3_FACTORY).deployCreate3(campaignSalt, campaignInitCode));

            if (i == 0) {
                continue;
            }

            vm.broadcast(deployer);
            Votemarket(votemarket).setRemote(address(campaignRemoteManager));

            vm.broadcast(deployer);
            Votemarket(votemarket).transferGovernance(address(governance));
        }
    }
}
