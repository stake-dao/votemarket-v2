// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/oracle/Proof.t.sol";

address constant CRV_ACCOUNT = 0x52f541764E6e90eeBc5c21Ff570De0e2D63766B6;
address constant CRV_GAUGE = 0x16A3a047fC1D388d5846a73ACDb475b11228c299;
uint256 constant CRV_BLOCK_NUMBER = 20_449_552;

uint256 constant CRV_LAST_USER_VOTE_SLOT = 11;
uint256 constant CRV_USER_SLOPE_SLOT = 9;
uint256 constant CRV_WEIGHT_SLOT = 12;

contract CRV_Platform is
    ProofCorrectnessTest(
        CRV_ACCOUNT,
        CRV_GAUGE,
        CRV_BLOCK_NUMBER,
        CRV_LAST_USER_VOTE_SLOT,
        CRV_USER_SLOPE_SLOT,
        CRV_WEIGHT_SLOT
    )
{}

address constant BAL_ACCOUNT = 0xea79d1A83Da6DB43a85942767C389fE0ACf336A5;
address constant BAL_GAUGE = 0xDc2Df969EE5E66236B950F5c4c5f8aBe62035df2;
uint256 constant BAL_BLOCK_NUMBER = 20_463_250;

uint256 constant BAL_LAST_USER_VOTE_SLOT = 1000000007;
uint256 constant BAL_USER_SLOPE_SLOT = 1000000005;
uint256 constant BAL_WEIGHT_SLOT = 1000000008;

contract BAL_Platform is
    ProofCorrectnessTest(
        BAL_ACCOUNT,
        BAL_GAUGE,
        BAL_BLOCK_NUMBER,
        BAL_LAST_USER_VOTE_SLOT,
        BAL_USER_SLOPE_SLOT,
        BAL_WEIGHT_SLOT
    )
{}

address constant FXN_ACCOUNT = 0x75736518075a01034fa72D675D36a47e9B06B2Fb;
address constant FXN_GAUGE = 0xDF7fbDBAE50C7931a11765FAEd9fe1A002605B55;
uint256 constant FXN_BLOCK_NUMBER = 20_463_250; 

uint256 constant FXN_LAST_USER_VOTE_SLOT = 1000000010;
uint256 constant FXN_USER_SLOPE_SLOT = 1000000008;
uint256 constant FXN_WEIGHT_SLOT = 1000000011;  

contract FXN_Platform is
    ProofCorrectnessTest(
        FXN_ACCOUNT,
        FXN_GAUGE,
        FXN_BLOCK_NUMBER,
        FXN_LAST_USER_VOTE_SLOT,
        FXN_USER_SLOPE_SLOT,
        FXN_WEIGHT_SLOT
    )
{}