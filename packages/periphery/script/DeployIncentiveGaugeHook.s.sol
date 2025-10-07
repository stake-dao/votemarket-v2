// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";
import {IncentiveGaugeHook} from "src/hooks/IncentiveGaugeHook.sol";

interface ImmutableCreate2Factory {
    function safeCreate2(bytes32, bytes memory) external;
}

contract DeployIncentiveGaugeHook is Script {
    address deployer = 0x428419Ad92317B09FE00675F181ac09c87D16450;

    function run() public {
        vm.startBroadcast(deployer);

        // Deploy hook
        bytes memory args = abi.encode(
            deployer,
            604800,
            0xf7753e64debD4548a6Cdb964D77b0CC408440E13
        );

        ImmutableCreate2Factory factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

        bytes32 initalizeCode = keccak256(abi.encodePacked(type(IncentiveGaugeHook).creationCode, args));

        bytes32 salt = bytes32(
            abi.encodePacked(
                bytes20(deployer), // must match caller
                uint96(1)            // free entropy
            )
        );

        factory.safeCreate2(salt, abi.encodePacked(type(IncentiveGaugeHook).creationCode, args));

        // Enable votemarkets
        IncentiveGaugeHook hook = IncentiveGaugeHook(address(0x58A64Af9267cBE345b765b9A3eDb5337d7cd0229));
        hook.enableVotemarket(address(0xDD2FaD5606cD8ec0c3b93Eb4F9849572b598F4c7)); // BAL
        hook.enableVotemarket(address(0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9)); // CRV

        vm.stopBroadcast();
    }
}
