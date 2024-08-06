// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IOracleLens {
    function canClaim(address account, address gauge, uint256 epoch) external view returns (bool);
    function getTotalVotesPerEpoch(address gauge, uint256 epoch) external view returns (uint256);
    function getVoteAccountPerEpoch(address account, address gauge, uint256 epoch) external view returns (uint256);
}
