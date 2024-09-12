// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import { Votemarket } from "../../votemarket/src/Votemarket.sol";
import { Oracle } from "../../votemarket/src/oracle/Oracle.sol";

contract DeployVotemarketScenarios is Script {
    address public constant DEPLOYER = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;

    struct Action {
        uint256 ID;
        bytes data;
    }

    function run() public {
        vm.startBroadcast(DEPLOYER);
        Oracle oracle = new Oracle();
        Votemarket votemarket = new Votemarket(DEPLOYER, address(oracle), DEPLOYER, 7 days, 2);

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/packages/mock-data/json/scenario_output.json");
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);

        Action[] memory actions = abi.decode(data, (Action[]));
        for (uint256 i = 0; i < data.length; i ++) {
            if (actions[i].ID == 1) {
                (bool success, ) = address(votemarket).call(actions[i].data);
                require(success, "Call failed");
            } else if (actions[i].ID == 2) {
                (bool success, ) = address(oracle).call(actions[i].data);
                require(success, "Call failed");
            } else if (actions[i].ID == 3) {
                vm.skip(uint256(bytes32(actions[i].data)));
            }
        }

        vm.stopBroadcast();
    }
}