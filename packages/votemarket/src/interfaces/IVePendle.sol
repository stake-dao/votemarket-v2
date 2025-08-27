// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface IVePendle {
    function positionData(address) external view returns (uint128,uint128);
    function balanceOf(address) external view returns (uint256);
}
