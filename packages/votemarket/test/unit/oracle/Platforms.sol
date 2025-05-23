// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/oracle/Proof.t.sol";

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
*/

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

/*
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
