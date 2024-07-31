// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// @notice Oracle contract to read voting values from the Gauge Controller.
//// WIP IMPLEMENTATION
contract Oracle {
    ////////////////////////////////////////////////////////////////
    /// --- DATA STRUCTURE DEFINITIONS
    ///////////////////////////////////////////////////////////////

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Governance address.
    address public governance;

    /// @notice Mapping of addresses authorized to insert data into the contract.
    mapping(address => bool) public authorizedDataProviders;

    /// @notice Mapping of Timestamp => Block Number.
    mapping(uint256 => uint256) public epochBlockNumber;

    /// @notice Mapping of Gauge => Epoch => Point Weight Struct.
    mapping(address => mapping(uint256 => Point)) public pointByEpoch;

    /// @notice Mapping of Address => Epoch => Voted Slope Struct.
    mapping(address => mapping(uint256 => VotedSlope)) public votedSlopeByEpoch;

    constructor() {
        governance = msg.sender;
    }

    ////////////////////////////////////////////////////////////////
    /// --- EVENTS & ERRORS
    ///////////////////////////////////////////////////////////////

    error AUTH_GOVERNANCE_ONLY();
    error NOT_AUTHORIZED_DATA_PROVIDER();

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyAuthorizedDataProvider() {
        if (!authorizedDataProviders[msg.sender]) revert NOT_AUTHORIZED_DATA_PROVIDER();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- INSERTION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Insert the block number for an epoch.
    function insertBlockNumber(uint256 epoch, uint256 blockNumber) external onlyAuthorizedDataProvider {
        epochBlockNumber[epoch] = blockNumber;
    }

    /// @notice Insert a point for an epoch and gauge.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @param point Point struct.
    function insertPoint(address gauge, uint256 epoch, Point memory point) external onlyAuthorizedDataProvider {
        pointByEpoch[gauge][epoch] = point;
    }

    /// @notice Insert a voted slope for an epoch and gauge.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @param votedSlope Voted slope struct.
    function insertVotedSlope(address gauge, uint256 epoch, VotedSlope memory votedSlope)
        external
        onlyAuthorizedDataProvider
    {
        votedSlopeByEpoch[gauge][epoch] = votedSlope;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    function setAuthorizedDataProvider(address dataProvider) external onlyGovernance {
        authorizedDataProviders[dataProvider] = true;
    }

    function revokeAuthorizedDataProvider(address dataProvider) external onlyGovernance {
        authorizedDataProviders[dataProvider] = false;
    }
}