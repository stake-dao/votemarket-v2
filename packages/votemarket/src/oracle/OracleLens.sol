// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

///  Project Interfaces
import "src/interfaces/IOracle.sol";

/// @notice Oracle Lens contract to read from the Oracle contract and expose data to the Votemarket contract.
contract OracleLens {
    address public immutable oracle;

    error STATE_NOT_UPDATED();

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {
        IOracle.Point memory weight = IOracle(oracle).pointByEpoch(gauge, epoch);
        if (weight.lastUpdate == 0) revert STATE_NOT_UPDATED();

        return weight.bias;
    }

    function canClaim(address account, address gauge, uint256 epoch) external view returns (bool) {
        IOracle.VotedSlope memory account_ = IOracle(oracle).votedSlopeByEpoch(account, gauge, epoch);
        if (account_.lastUpdate == 0) revert STATE_NOT_UPDATED();

        if (account_.slope == 0 || epoch >= account_.end || epoch <= account_.lastVote) return false;

        return true;
    }

    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {
        IOracle.VotedSlope memory account_ = IOracle(oracle).votedSlopeByEpoch(account, gauge, epoch);
        if (account_.lastUpdate == 0) revert STATE_NOT_UPDATED();

        if (epoch >= account_.end) return 0;

        return account_.slope * (account_.end - epoch);
    }
}
