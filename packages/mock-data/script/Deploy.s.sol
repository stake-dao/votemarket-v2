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

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/json/scenario_output.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        Action[] memory actions = abi.decode(data, (Action[]));

        console.log("decoded");
        for (uint256 i = 0; i < actions.length; i ++) {
            if (actions[i].ID == 1) {
                (bool success, ) = address(votemarket).call(actions[i].data);
                require(success, "Call failed");
            } else if (actions[i].ID == 2) {
                (bool success, ) = address(oracle).call(actions[i].data);
                require(success, "Call failed");
            } else if (actions[i].ID == 3) {

                console.logBytes(actions[i].data);
                //skip(bytesToUint(actions[i].data));

                string[] memory calldataPython = new string[](3);
                calldataPython[0] = "python3";
                calldataPython[1] = string(abi.encodePacked(vm.projectRoot(), "/python/time_jump.py"));
                calldataPython[2] = "456";
                bytes memory result = vm.ffi(calldataPython);
                console.logBytes(result);
                (bool success) = abi.decode(result,(bool));
                console.log("success");
                console.log(success);
                require(success, "Call failed");
            }
        }

        vm.stopBroadcast();
    }
}