// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "@forge-std/src/Script.sol";
import "@forge-std/src/Test.sol";
import "@forge-std/src/mocks/MockERC20.sol";
import { Votemarket } from "@votemarket/Votemarket.sol";
import { Oracle } from "@votemarket/oracle/Oracle.sol";

contract DeployVotemarketScenarios is Script, Test {
    address public DEPLOYER = vm.envAddress("ADDRESS");

    struct Action {
        uint256 ID;
        bytes data;
    }

    function toString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";
         
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
         
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
         
        return string(str);
    }

    function run() public {
        vm.startBroadcast();

        address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

        Oracle oracle = new Oracle(DEPLOYER);
        Votemarket votemarket = new Votemarket(DEPLOYER, address(oracle), DEPLOYER, 7 days, 2);

        MockERC20(CRV).approve(address(votemarket), type(uint256).max);

        string[] memory calldataPython = new string[](4);
        calldataPython[0] = "python3";
        calldataPython[1] = string(abi.encodePacked(vm.projectRoot(), "/python/run_deployment.py"));
        calldataPython[2] = toString(address(votemarket));
        calldataPython[3] = toString(address(oracle)); 
        vm.ffi(calldataPython);

        vm.stopBroadcast();
    }
}