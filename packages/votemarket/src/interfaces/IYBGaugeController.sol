// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IYBGaugeController {
    function last_user_vote(address, address) external view returns (uint256);
    function vote_user_slopes(address, address) external view returns (uint256, uint256, uint256, uint256);
    function point_weight(address) external view returns (uint256, uint256);
}
