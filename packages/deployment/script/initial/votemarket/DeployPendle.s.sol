// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";
import {BasePendle} from "script/initial/votemarket/BasePendle.sol";

contract DeployPendle is BasePendle {
    address public constant PENDLE_GAUGE_CONTROLLER = address(0x44087E105137a5095c008AaB6a6530182821F2F0);

    function run() public {
        /// Pendle
        super.run({
            gaugeController: PENDLE_GAUGE_CONTROLLER,
            minPeriods: 2,
            epochLength: 1 weeks,
            lastUserVoteSlot: 1,
            userSlopeSlot: 162,
            weightSlot: 161
        });
    }
}