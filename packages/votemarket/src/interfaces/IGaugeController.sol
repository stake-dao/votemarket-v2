// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IGaugeController {
    function last_user_vote(address, address) external view returns (uint256);
    function vote_user_slopes(address, address) external view returns (uint256, uint256);
    function points_weight(address, uint256) external view returns (uint256, uint256);
}
