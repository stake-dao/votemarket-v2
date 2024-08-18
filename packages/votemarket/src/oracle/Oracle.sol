// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

///  Project Interfaces
import "src/interfaces/IOracle.sol";

/// @notice Oracle contract to store voting values from the Gauge Controller.
contract Oracle {
    ////////////////////////////////////////////////////////////////
    /// --- DATA STRUCTURE DEFINITIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Curve Gauge Controller Structs appended with last update timestamp.
    struct Point {
        uint256 bias;
        uint256 lastUpdate;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
        uint256 lastVote;
        uint256 lastUpdate;
    }

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Governance address.
    address public governance;

    /// @notice Future governance address.
    address public futureGovernance;

    /// @notice Mapping of addresses authorized to insert data into the contract.
    mapping(address => bool) public authorizedDataProviders;

    /// @notice  Mapping of addresses authorized to insert block numbers into the contract.
    mapping(address => bool) public authorizedBlockNumberProviders;

    /// @notice Mapping of Timestamp => Block Header Data.
    mapping(uint256 => StateProofVerifier.BlockHeader) public epochBlockNumber;

    /// @notice Mapping of Gauge => Epoch => Point Weight Struct.
    mapping(address => mapping(uint256 => Point)) public pointByEpoch;

    /// @notice Mapping of Address => Gauge => Epoch => Voted Slope Struct.
    mapping(address => mapping(address => mapping(uint256 => VotedSlope))) public votedSlopeByEpoch;

    constructor(address _governance) {
        governance = _governance;
    }

    ////////////////////////////////////////////////////////////////
    /// --- EVENTS & ERRORS
    ///////////////////////////////////////////////////////////////

    error ZERO_ADDRESS();
    error INVALID_EPOCH();
    error AUTH_GOVERNANCE_ONLY();
    error NOT_AUTHORIZED_DATA_PROVIDER();
    error NOT_AUTHORIZED_BLOCK_NUMBER_PROVIDER();

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier validEpoch(uint256 epoch) {
        StateProofVerifier.BlockHeader memory blockData = epochBlockNumber[epoch];
        if (blockData.number == 0) revert INVALID_EPOCH();
        _;
    }

    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    modifier onlyAuthorizedDataProvider() {
        if (!authorizedDataProviders[msg.sender]) revert NOT_AUTHORIZED_DATA_PROVIDER();
        _;
    }

    modifier onlyAuthorizedBlockNumberProvider() {
        if (!authorizedBlockNumberProviders[msg.sender]) revert NOT_AUTHORIZED_BLOCK_NUMBER_PROVIDER();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- INSERTION LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Insert the block number for an epoch.
    function insertBlockNumber(uint256 epoch, StateProofVerifier.BlockHeader memory blockData)
        external
        onlyAuthorizedBlockNumberProvider
    {
        epochBlockNumber[epoch] = blockData;
    }

    /// @notice Insert a point for an epoch and gauge.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @param point Point struct.
    function insertPoint(address gauge, uint256 epoch, Point memory point)
        external
        validEpoch(epoch)
        onlyAuthorizedDataProvider
    {
        pointByEpoch[gauge][epoch] = point;
    }

    /// @notice Insert a voted slope for an epoch and gauge for a voter.
    /// @param voter Voter address.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @param slope Voted slope struct.
    function insertAddressEpochData(address voter, address gauge, uint256 epoch, VotedSlope memory slope)
        external
        validEpoch(epoch)
        onlyAuthorizedDataProvider
    {
        votedSlopeByEpoch[voter][gauge][epoch] = slope;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    function setAuthorizedBlockNumberProvider(address blockNumberProvider) external onlyGovernance {
        authorizedBlockNumberProviders[blockNumberProvider] = true;
    }

    function revokeAuthorizedBlockNumberProvider(address blockNumberProvider) external onlyGovernance {
        authorizedBlockNumberProviders[blockNumberProvider] = false;
    }

    function setAuthorizedDataProvider(address dataProvider) external onlyGovernance {
        authorizedDataProviders[dataProvider] = true;
    }

    function revokeAuthorizedDataProvider(address dataProvider) external onlyGovernance {
        authorizedDataProviders[dataProvider] = false;
    }

    function transferGovernance(address _governance) external onlyGovernance {
        if (_governance == address(0)) revert ZERO_ADDRESS();

        futureGovernance = _governance;
    }

    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }
}
