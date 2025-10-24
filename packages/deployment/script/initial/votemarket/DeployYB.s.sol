// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";
import {BaseYB} from "script/initial/votemarket/BaseYB.sol";

contract DeployYB is BaseYB {
    address public constant YB_GAUGE_CONTROLLER = address(0x1Be14811A3a06F6aF4fA64310a636e1Df04c1c21);

    function run() public {
        /// Pendle
        super.run({
            gaugeController: YB_GAUGE_CONTROLLER,
            minPeriods: 2,
            epochLength: 1 weeks,
            lastUserVoteSlot: 1000000005,
            userSlopeSlot: 1000000003,
            weightSlot: 1000000006
        });
    }
}