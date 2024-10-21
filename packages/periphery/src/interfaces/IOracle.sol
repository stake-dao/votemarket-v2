// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {StateProofVerifier} from "@votemarket/src/interfaces/IOracle.sol";

interface IOracle {
    function insertBlockNumber(uint256 epoch, StateProofVerifier.BlockHeader memory blockData) external;
    function epochBlockNumber(uint256 epoch) external view returns (StateProofVerifier.BlockHeader memory);
}
