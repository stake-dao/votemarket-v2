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

    function run() public {
        vm.startBroadcast();

        address CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

        Oracle oracle = new Oracle(DEPLOYER);
        Votemarket votemarket = new Votemarket(DEPLOYER, address(oracle), DEPLOYER, 7 days, 2);

        MockERC20(CRV).approve(address(votemarket), type(uint256).max);

        string[] memory calldataPython = new string[](3);
        calldataPython[0] = "python3";
        calldataPython[1] = string(abi.encodePacked(vm.projectRoot(), "/python/run_deployment.py"));
        calldataPython[2] = string(address(votemarket));
        calldataPython[3] = string(address(oracle)); 

        vm.stopBroadcast();
    }
}