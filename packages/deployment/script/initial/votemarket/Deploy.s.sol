// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";
import {Base} from "script/initial/votemarket/Base.sol";

contract Deploy is Base {
    address public constant CURVE_GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);

    address public constant BALANCER_GAUGE_CONTROLLER = address(0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD);

    address public constant FXN_GAUGE_CONTROLLER = address(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37);

    function run() public {
        /// Curve
        super.run({
            gaugeController: CURVE_GAUGE_CONTROLLER,
            minPeriods: 2,
            epochLength: 1 weeks,
            lastUserVoteSlot: 11,
            userSlopeSlot: 9,
            weightSlot: 12
        });
    }
}
