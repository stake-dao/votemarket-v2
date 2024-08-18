// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";

///  Project Interfaces
import "src/interfaces/IOracle.sol";

/// @notice Oracle Lens contract to read from the Oracle contract and expose data to the Votemarket contract.
/// @dev It should always revert if the epoch data is not updated.
contract OracleLens {
    /// @notice Oracle address.
    address public immutable oracle;

    /// @notice Thrown when the epoch data is not updated.
    error STATE_NOT_UPDATED();

    constructor(address _oracle) {
        oracle = _oracle;
    }

    /// @notice Checks if an account can claim rewards for a gauge and epoch.
    /// @param account Account address.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @return bool True if the account can claim, false otherwise.
    function canClaim(address account, address gauge, uint256 epoch) external view returns (bool) {
        IOracle.VotedSlope memory account_ = IOracle(oracle).votedSlopeByEpoch(account, gauge, epoch);
        if (account_.lastUpdate == 0) revert STATE_NOT_UPDATED();
        if (account_.slope == 0 || epoch >= account_.end || epoch <= account_.lastVote) return false;

        return true;
    }

    /// @notice Gets the total votes for a gauge and epoch.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @return uint256 Total votes.
    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {
        IOracle.Point memory weight = IOracle(oracle).pointByEpoch(gauge, epoch);
        if (weight.lastUpdate == 0) revert STATE_NOT_UPDATED();

        return weight.bias;
    }

    /// @notice Gets the account votes for a gauge and epoch.
    /// @param account Account address.
    /// @param gauge Gauge address.
    /// @param epoch Epoch number.
    /// @return uint256 Account votes.
    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {
        IOracle.VotedSlope memory account_ = IOracle(oracle).votedSlopeByEpoch(account, gauge, epoch);
        if (account_.lastUpdate == 0) revert STATE_NOT_UPDATED();
        if (epoch >= account_.end) return 0;

        return account_.slope * (account_.end - epoch);
    }
}
