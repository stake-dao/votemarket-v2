// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IPendleOracle.sol";

interface IVerifierBasePendle {
    function ORACLE() external view returns (IPendleOracle);
    function SOURCE_GAUGE_CONTROLLER_HASH() external view returns (bytes32);

    function WEIGHT_MAPPING_SLOT() external view returns (uint256);
    function LAST_VOTE_MAPPING_SLOT() external view returns (uint256);
    function USER_SLOPE_MAPPING_SLOT() external view returns (uint256);

    function setBlockData(bytes calldata blockHeader, bytes calldata proof) external returns (bytes32);
    function setAccountData(address account, address gauge, uint256 epoch, bytes calldata proof)
        external
        returns (IPendleOracle.VotedSlope memory);
    function setPointData(address gauge, uint256 epoch, bytes calldata proof) external returns (IPendleOracle.Point memory);
    function setAuthorizedDataProvider(address dataProvider) external;
}
