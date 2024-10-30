// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Bundler} from "@periphery/src/bundler/Bundler.sol";
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
    address public laPoste = 0x345000000000FD99009B2BF0fb373Ca70f4C0047;
    address public tokenFactory = 0x00000000A551c9435E002a5d75DC2EE3C0644400;

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    Bundler public bundler;
    CampaignRemoteManager public campaignRemoteManager;

    string[] public chains = ["mainnet", "arbitrum", "optimism", "base", "polygon"];

    function run() public {
        bytes32 campaignSalt = bytes32(0x606a503e5178908f10597894b35b2be8685eab9000b35dad48ecf0ff03b2f4c8);
        bytes memory campaignInitCode = abi.encodePacked(
            type(CampaignRemoteManager).creationCode, abi.encode(votemarket, laPoste, tokenFactory, deployer)
        );

        bytes32 bundlerSalt = bytes32(0x606a503e5178908f10597894b35b2be8685eab9000b35dad48ecf0ff03b2f4c9);
        bytes memory bundlerInitCode = abi.encodePacked(type(Bundler).creationCode, abi.encode(laPoste));

        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));

            vm.broadcast(deployer);
            campaignRemoteManager =
                CampaignRemoteManager(ICreate3Factory(CREATE3_FACTORY).deployCreate3(campaignSalt, campaignInitCode));

            if (i == 0) continue;
            vm.broadcast(deployer);
            bundler = Bundler(ICreate3Factory(CREATE3_FACTORY).deployCreate3(bundlerSalt, bundlerInitCode));
        }
    }
}
