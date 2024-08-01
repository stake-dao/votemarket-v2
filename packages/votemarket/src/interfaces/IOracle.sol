// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@utils/StateProofVerifier.sol";

interface IOracle {
    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
        uint256 lastVote;
    }

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    function insertBlockNumber(uint256 epoch, StateProofVerifier.BlockHeader memory blockData) external;

    function insertPoint(address gauge, uint256 epoch, Point memory point) external;

    function insertAddressEpochData(address voter, address gauge, uint256 epoch, VotedSlope memory slope) external;
}
