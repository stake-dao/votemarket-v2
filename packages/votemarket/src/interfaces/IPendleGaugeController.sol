// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

struct VeBalance {
    uint128 bias;
    uint128 slope;
}

struct UserPoolData {
    uint64 weight;
    VeBalance vote;
}

interface IPendleGaugeController {
    function owner() external view returns (address);
    function getUserPoolVote(address, address) external view returns (UserPoolData memory);
    function getPoolTotalVoteAt(address, uint128) external view returns (uint128);
}
