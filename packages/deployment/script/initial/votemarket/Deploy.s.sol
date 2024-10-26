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
        super.run(CURVE_GAUGE_CONTROLLER, 2, 1 weeks, 11, 9, 12);

        /// Balancer
        super.run(BALANCER_GAUGE_CONTROLLER, 2, 1 weeks, 1000000007, 1000000005, 1000000008);

        /// FXN
        super.run(FXN_GAUGE_CONTROLLER, 2, 1 weeks, 1000000010, 1000000008, 1000000011);
    }
}
