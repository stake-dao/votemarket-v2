// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";
import {CampaignRemoteManager} from "src/remote/CampaignRemoteManager.sol";

interface ImmutableCreate2Factory {
    function safeCreate2(bytes32, bytes memory) external;
}

contract DeployRemoteManager is Script {
    address deployer = 0x8898502BA35AB64b3562aBC509Befb7Eb178D4df;

    function run() public {
        vm.createSelectFork("mainnet");
        vm.startBroadcast(deployer);

        bytes memory args = abi.encode(
            0xF0000058000021003E4754dCA700C766DE7601C2,
            0x96006425Da428E45c282008b00004a00002B345e,
            0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765
        );

        ImmutableCreate2Factory factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

        bytes32 initalizeCode = keccak256(abi.encodePacked(type(CampaignRemoteManager).creationCode, args));
        console.logBytes32(initalizeCode);

        address expectedAddress = 0x000000009dF57105d76B059178989E01356e4b45;
        bytes32 salt = bytes32(0x8898502ba35ab64b3562abc509befb7eb178d4df75e47f6342d5279f66004005);

        factory.safeCreate2(salt, abi.encodePacked(type(CampaignRemoteManager).creationCode, args));

        vm.stopBroadcast();
    }
}
