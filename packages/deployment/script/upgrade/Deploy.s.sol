// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import {Base} from "script/upgrade/Base.sol";

contract Deploy is Base {
    address public constant CURVE_ORACLE_LENS = address(0x99EDB5782da5D799dd16a037FDbc00a1494b9Ead);
    address public constant BALANCER_ORACLE_LENS = address(0x0000000064Ef5Bf60FB64BbCe5D756268cB4e7f7);
    address public constant FXN_ORACLE_LENS = address(0x00000000e4172A7A8Edf7C17B4C1793AF0EA76bB);

    function run() public {
        /// Curve
        super.run({minPeriods: 2, epochLength: 1 weeks, oracleLensAddress: CURVE_ORACLE_LENS});

        /// Balancer
        // super.run({minPeriods: 2, epochLength: 1 weeks, oracleLensAddress: BALANCER_ORACLE_LENS});

        /// FXN
        // super.run({minPeriods: 2, epochLength: 1 weeks, oracleLensAddress: FXN_ORACLE_LENS});
    }
}
