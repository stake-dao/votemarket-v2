// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@utils/StateProofVerifier.sol";

interface IOracle {
    struct VotedSlope {
        uint256 slope;
        uint256 end;
        uint256 lastVote;
        uint256 lastUpdate;
    }

    struct Point {
        uint256 bias;
        uint256 lastUpdate;
    }

    function pointByEpoch(address gauge, uint256 epoch) external view returns (Point memory);
    function epochBlockNumber(uint256 epoch) external view returns (StateProofVerifier.BlockHeader memory);
    function votedSlopeByEpoch(address account, address gauge, uint256 epoch)
        external
        view
        returns (VotedSlope memory);

    function insertBlockNumber(uint256 epoch, StateProofVerifier.BlockHeader memory blockData) external;

    function insertPoint(address gauge, uint256 epoch, Point memory point) external;

    function insertAddressEpochData(address voter, address gauge, uint256 epoch, VotedSlope memory slope) external;
}
