// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IOracleLens {
    function canClaim(address account, address gauge, uint256 epoch) external view returns (bool);
    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256);
    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256);
}
