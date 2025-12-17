// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import {BaseV2} from "script/verifier/BaseV2.sol";

contract DeployV2 is BaseV2 {
    address constant CRV_GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);
    address constant CRV_ORACLE = address(0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8);
    uint256 constant CRV_LAST_USER_VOTE_SLOT = 11;
    uint256 constant CRV_USER_SLOPE_SLOT = 9;
    uint256 constant CRV_WEIGHT_SLOT = 12;

    address constant BAL_GAUGE_CONTROLLER = address(0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD);
    address constant BAL_ORACLE = address(0x000000009f42db5807378c374da13c54C856c29c);
    uint256 constant BAL_LAST_USER_VOTE_SLOT = 1000000007;
    uint256 constant BAL_USER_SLOPE_SLOT = 1000000005;
    uint256 constant BAL_WEIGHT_SLOT = 1000000008;

    address constant FXN_GAUGE_CONTROLLER = address(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37);
    address constant FXN_ORACLE = address(0x000000009271842F0D4Db92a7Ef5544D1F70bC1A);
    uint256 constant FXN_LAST_USER_VOTE_SLOT = 1000000010;
    uint256 constant FXN_USER_SLOPE_SLOT = 1000000008;
    uint256 constant FXN_WEIGHT_SLOT = 1000000011;

    address constant PENDLE_GAUGE_CONTROLLER = address(0x44087E105137a5095c008AaB6a6530182821F2F0);
    address constant PENDLE_ORACLE = address(0x16048a62aaEB91b922f1020469B7bA200c1c41E9);
    uint256 constant PENDLE_LAST_USER_VOTE_SLOT = 1;
    uint256 constant PENDLE_USER_SLOPE_SLOT = 162;
    uint256 constant PENDLE_WEIGHT_SLOT = 161;

    address constant YB_GAUGE_CONTROLLER = address(0x1Be14811A3a06F6aF4fA64310a636e1Df04c1c21);
    address constant YB_ORACLE = address(0x00C1967Ff183ae659095b82E47Fd6b242e49Da46);
    uint256 constant YB_LAST_USER_VOTE_SLOT = 1000000005;
    uint256 constant YB_USER_SLOPE_SLOT = 1000000003;
    uint256 constant YB_WEIGHT_SLOT = 1000000006;

    function run() public {
        /// Curve
        /*bytes32 salt = bytes32("CurveVerifierV49798502ba35ab64b3");
        bytes memory initCode = getInitCode(
            CRV_ORACLE, CRV_GAUGE_CONTROLLER, CRV_LAST_USER_VOTE_SLOT, CRV_USER_SLOPE_SLOT, CRV_WEIGHT_SLOT
        );
        super.deploy({
            oracle: CRV_ORACLE,
            gaugeController: CRV_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: CRV_LAST_USER_VOTE_SLOT,
            userSlopeSlot: CRV_USER_SLOPE_SLOT,
            weightSlot: CRV_WEIGHT_SLOT
        });
        /// Balancer
        salt = bytes32("BalancerVerifierV49798502ba35a");
        initCode = getInitCodeV2(
            BAL_ORACLE, BAL_GAUGE_CONTROLLER, BAL_LAST_USER_VOTE_SLOT, BAL_USER_SLOPE_SLOT, BAL_WEIGHT_SLOT
        );
        super.deploy({
            oracle: BAL_ORACLE,
            gaugeController: BAL_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: BAL_LAST_USER_VOTE_SLOT,
            userSlopeSlot: BAL_USER_SLOPE_SLOT,
            weightSlot: BAL_WEIGHT_SLOT
        });*/

        /// FXN
        bytes32 salt = bytes32("FXNVerifierV49798502ba35ab64b2");
        bytes memory  initCode = getInitCodeV2(
            FXN_ORACLE, FXN_GAUGE_CONTROLLER, FXN_LAST_USER_VOTE_SLOT, FXN_USER_SLOPE_SLOT, FXN_WEIGHT_SLOT
        );
        super.deploy({
            oracle: FXN_ORACLE,
            gaugeController: FXN_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: FXN_LAST_USER_VOTE_SLOT,
            userSlopeSlot: FXN_USER_SLOPE_SLOT,
            weightSlot: FXN_WEIGHT_SLOT
        });

        /// Pendle
        /*salt = bytes32("PENDLEVerifierV49798502ba35a");
        initCode = getInitCodePendle(
            PENDLE_ORACLE,
            PENDLE_GAUGE_CONTROLLER,
            PENDLE_LAST_USER_VOTE_SLOT,
            PENDLE_USER_SLOPE_SLOT,
            PENDLE_WEIGHT_SLOT
        );
        super.deploy({
            oracle: PENDLE_ORACLE,
            gaugeController: PENDLE_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: PENDLE_LAST_USER_VOTE_SLOT,
            userSlopeSlot: PENDLE_USER_SLOPE_SLOT,
            weightSlot: PENDLE_WEIGHT_SLOT
        });

        /// Yb
        salt = bytes32("YBVerifierV49798502ba35ab64b3");
        initCode =
            getInitCodeYb(YB_ORACLE, YB_GAUGE_CONTROLLER, YB_LAST_USER_VOTE_SLOT, YB_USER_SLOPE_SLOT, YB_WEIGHT_SLOT);
        super.deploy({
            oracle: YB_ORACLE,
            gaugeController: YB_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: YB_LAST_USER_VOTE_SLOT,
            userSlopeSlot: YB_USER_SLOPE_SLOT,
            weightSlot: YB_WEIGHT_SLOT
        });*/
    }
}