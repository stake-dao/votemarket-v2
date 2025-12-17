// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import {Base} from "script/verifier/Base.sol";

contract Deploy is Base {
    address constant CRV_GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);
    address constant CRV_ORACLE = address(0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8);
    address constant CRV_VERIFIER = address(0x2Fa15A44eC5737077a747ed93e4eBD5b4960a465);
    uint256 constant CRV_LAST_USER_VOTE_SLOT = 11;
    uint256 constant CRV_USER_SLOPE_SLOT = 9;
    uint256 constant CRV_WEIGHT_SLOT = 12;

    address constant BAL_GAUGE_CONTROLLER = address(0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD);
    address constant BAL_ORACLE = address(0x000000009f42db5807378c374da13c54C856c29c);
    address constant BAL_VERIFIER = address(0x00000000888Fb15FfbBa217F302a77FA0226Ce16);
    uint256 constant BAL_LAST_USER_VOTE_SLOT = 1000000007;
    uint256 constant BAL_USER_SLOPE_SLOT = 1000000005;
    uint256 constant BAL_WEIGHT_SLOT = 1000000008;

    address constant FXN_GAUGE_CONTROLLER = address(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37);
    address constant FXN_ORACLE = address(0x000000009271842F0D4Db92a7Ef5544D1F70bC1A);
    address constant FXN_VERIFIER = address(0x00000000c6906194269c9955A9E5DEF4e018CDd5);
    uint256 constant FXN_LAST_USER_VOTE_SLOT = 1000000010;
    uint256 constant FXN_USER_SLOPE_SLOT = 1000000008;
    uint256 constant FXN_WEIGHT_SLOT = 1000000011;

    function run() public {
        /// Curve
        bytes32 salt = bytes32("CurveVerifierV3");
        bytes memory initCode = getInitCode(
            CRV_ORACLE, CRV_GAUGE_CONTROLLER, CRV_LAST_USER_VOTE_SLOT, CRV_USER_SLOPE_SLOT, CRV_WEIGHT_SLOT
        );
        super.run({
            oracle: CRV_ORACLE,
            oldVerifier: CRV_VERIFIER,
            gaugeController: CRV_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: CRV_LAST_USER_VOTE_SLOT,
            userSlopeSlot: CRV_USER_SLOPE_SLOT,
            weightSlot: CRV_WEIGHT_SLOT
        });
        /// Balancer
        salt = bytes32("BalancerVerifierV3");
        initCode = getInitCodeV2(
            BAL_ORACLE, BAL_GAUGE_CONTROLLER, BAL_LAST_USER_VOTE_SLOT, BAL_USER_SLOPE_SLOT, BAL_WEIGHT_SLOT
        );
        super.run({
            oracle: BAL_ORACLE,
            oldVerifier: BAL_VERIFIER,
            gaugeController: BAL_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: BAL_LAST_USER_VOTE_SLOT,
            userSlopeSlot: BAL_USER_SLOPE_SLOT,
            weightSlot: BAL_WEIGHT_SLOT
        });

        /// FXN
        salt = bytes32("FXNVerifierV3");
        initCode = getInitCodeV2(
            FXN_ORACLE, FXN_GAUGE_CONTROLLER, FXN_LAST_USER_VOTE_SLOT, FXN_USER_SLOPE_SLOT, FXN_WEIGHT_SLOT
        );
        super.run({
            oracle: FXN_ORACLE,
            oldVerifier: FXN_VERIFIER,
            gaugeController: FXN_GAUGE_CONTROLLER,
            initCode: initCode,
            salt: salt,
            lastUserVoteSlot: FXN_LAST_USER_VOTE_SLOT,
            userSlopeSlot: FXN_USER_SLOPE_SLOT,
            weightSlot: FXN_WEIGHT_SLOT
        });
    }
}
