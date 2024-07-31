// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// @notice Oracle contract to read voting values from the Gauge Controller.
contract Oracle {
    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    /// @notice Mapping of addresses authorized to insert data into the contract.
    mapping(address => bool) public authorizedDataProviders;

    /// @notice Mapping of Timestamp => Block Number.
    mapping(uint256 => uint256) public epochBlockNumber;

    /// @notice Mapping of Gauge => Epoch => Point Weight Struct.
    mapping(address => mapping(uint256 => Point)) public pointByEpoch;

    /// @notice Mapping of Address => Epoch => Voted Slope Struct.
    mapping(address => mapping(uint256 => VotedSlope)) public votedSlopeByEpoch;
}
