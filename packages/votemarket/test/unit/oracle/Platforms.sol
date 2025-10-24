// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/oracle/Proof.t.sol";
import "test/unit/oracle/ProofPendle.t.sol";
import "test/unit/oracle/ProofCorrectnessTestYB.t.sol";

// Slots are different for each platform whever they've been compiled with different compiler versions,
// and if vyper or solidity.
/*
address constant CRV_GAUGE_CONTROLLER = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);
address constant CRV_ACCOUNT = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
address constant CRV_GAUGE = 0x16A3a047fC1D388d5846a73ACDb475b11228c299;
uint256 constant CRV_BLOCK_NUMBER = 20_449_552;

uint256 constant CRV_LAST_USER_VOTE_SLOT = 11;
uint256 constant CRV_USER_SLOPE_SLOT = 9;
uint256 constant CRV_WEIGHT_SLOT = 12;

contract CRV_Platform is
    ProofCorrectnessTest(
        CRV_GAUGE_CONTROLLER,
        CRV_ACCOUNT,
        CRV_GAUGE,
        CRV_BLOCK_NUMBER,
        CRV_LAST_USER_VOTE_SLOT,
        CRV_USER_SLOPE_SLOT,
        CRV_WEIGHT_SLOT,
        false
    )
{}

/*
address constant BAL_GAUGE_CONTROLLER = address(0xC128468b7Ce63eA702C1f104D55A2566b13D3ABD);
address constant BAL_ACCOUNT = 0xea79d1A83Da6DB43a85942767C389fE0ACf336A5;
address constant BAL_GAUGE = 0xDc2Df969EE5E66236B950F5c4c5f8aBe62035df2;
uint256 constant BAL_BLOCK_NUMBER = 22_084_453;
uint256 constant BAL_LAST_USER_VOTE_SLOT = 1000000007;
uint256 constant BAL_USER_SLOPE_SLOT = 1000000005;
uint256 constant BAL_WEIGHT_SLOT = 1000000008;

contract BAL_Platform is
    ProofCorrectnessTest(
        BAL_GAUGE_CONTROLLER,
        BAL_ACCOUNT,
        BAL_GAUGE,
        BAL_BLOCK_NUMBER,
        BAL_LAST_USER_VOTE_SLOT,
        BAL_USER_SLOPE_SLOT,
        BAL_WEIGHT_SLOT,
        true
    )
{}

address constant FXN_GAUGE_CONTROLLER = address(0xe60eB8098B34eD775ac44B1ddE864e098C6d7f37);
address constant FXN_ACCOUNT = 0x75736518075a01034fa72D675D36a47e9B06B2Fb;
address constant FXN_GAUGE = 0xDF7fbDBAE50C7931a11765FAEd9fe1A002605B55;
uint256 constant FXN_BLOCK_NUMBER = 20_563_250;

uint256 constant FXN_LAST_USER_VOTE_SLOT = 1000000010;
uint256 constant FXN_USER_SLOPE_SLOT = 1000000008;
uint256 constant FXN_WEIGHT_SLOT = 1000000011;


contract FXN_Platform is
    ProofCorrectnessTest(
        FXN_GAUGE_CONTROLLER,
        FXN_ACCOUNT,
        FXN_GAUGE,
        FXN_BLOCK_NUMBER,
        FXN_LAST_USER_VOTE_SLOT,
        FXN_USER_SLOPE_SLOT,
        FXN_WEIGHT_SLOT,
        true
    )
{}

address constant FXS_GAUGE_CONTROLLER = address(0x3669C421b77340B2979d1A00a792CC2ee0FcE737);
address constant FXS_ACCOUNT = 0xCd3a267DE09196C48bbB1d9e842D7D7645cE448f;
address constant FXS_GAUGE = 0x719505cB97DF15565255eb1bDe65586271dB873C;
uint256 constant FXS_BLOCK_NUMBER = 20_563_250;

uint256 constant FXS_LAST_USER_VOTE_SLOT = 1000000010;
uint256 constant FXS_USER_SLOPE_SLOT = 1000000008;
uint256 constant FXS_WEIGHT_SLOT = 1000000011;

contract FXS_Platform is
    ProofCorrectnessTest(
        FXS_GAUGE_CONTROLLER,
        FXS_ACCOUNT,
        FXS_GAUGE,
        FXS_BLOCK_NUMBER,
        FXS_LAST_USER_VOTE_SLOT,
        FXS_USER_SLOPE_SLOT,
        FXS_WEIGHT_SLOT,
        true
    )
{}
*/
/*
address constant PENDLE_GAUGE_CONTROLLER = address(0x44087E105137a5095c008AaB6a6530182821F2F0);
address constant PENDLE_ACCOUNT = 0xD8fa8dC5aDeC503AcC5e026a98F32Ca5C1Fa289A;
address constant PENDLE_GAUGE = 0x2f8159644f045A388c1FC954e795202Dc1d34308;
address constant PENDLE_VE = 0x4f30A9D41B80ecC5B94306AB4364951AE3170210;
uint256 constant PENDLE_BLOCK_NUMBER = 23123761;

uint256 constant PENDLE_LAST_USER_VOTE_SLOT = 1;
uint256 constant PENDLE_USER_SLOPE_SLOT = 162;
uint256 constant PENDLE_WEIGHT_SLOT = 161;

contract PENDLE_Platform is
    ProofCorrectnessTestPendle(
        PENDLE_GAUGE_CONTROLLER,
        PENDLE_ACCOUNT,
        PENDLE_GAUGE,
        PENDLE_BLOCK_NUMBER,
        PENDLE_LAST_USER_VOTE_SLOT,
        PENDLE_USER_SLOPE_SLOT,
        PENDLE_WEIGHT_SLOT,
        PENDLE_VE
    )
{}*/


address constant YB_GAUGE_CONTROLLER = address(0x1Be14811A3a06F6aF4fA64310a636e1Df04c1c21);
address constant YB_ACCOUNT = 0x29B6a3512FafeAce91433D278503ABC3D5aB5d12;
address constant YB_GAUGE = 0x37f45E64935e7B8383D2f034048B32770B04E8bd;
address constant YB_VE = 0x8235c179E9e84688FBd8B12295EfC26834dAC211;
uint256 constant YB_BLOCK_NUMBER = 23641535;

uint256 constant YB_LAST_USER_VOTE_SLOT = 1000000005;
uint256 constant YB_USER_SLOPE_SLOT = 1000000003;
uint256 constant YB_WEIGHT_SLOT = 1000000006;

contract YB_Platform is
    ProofCorrectnessTestYB(
        YB_GAUGE_CONTROLLER,
        YB_ACCOUNT,
        YB_GAUGE,
        YB_BLOCK_NUMBER,
        YB_LAST_USER_VOTE_SLOT,
        YB_USER_SLOPE_SLOT,
        YB_WEIGHT_SLOT,
        true
    )
{}