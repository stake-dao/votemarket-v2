// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {BundlerPendle} from "@periphery/src/bundler/BundlerPendle.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}

contract Deploy is Script {

    address public deployer = 0x428419Ad92317B09FE00675F181ac09c87D16450;
    address public laPoste = 0xF0000058000021003E4754dCA700C766DE7601C2;

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function run() public {
        vm.createSelectFork(vm.rpcUrl("arbitrum"));
        vm.startBroadcast(deployer);

        bytes32 salt = bytes32(0x5898502ba35ab64b3562abc509befb7eb178d4df0033a58e93d4505101a4684b);

        bytes memory initCode = abi.encodePacked(type(BundlerPendle).creationCode, abi.encode(laPoste));

        address bundler = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);

        vm.stopBroadcast();
    }
}