// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@utils/StateProofVerifier.sol";
import "@solady/src/utils/LibString.sol";

import "src/interfaces/IOracle.sol";

/// @notice Verify RLP proofs, and insert the data into oracle.
abstract contract RLPVerifier {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using LibString for address;
    using LibString for string;

    address public immutable ORACLE;
    bytes32 public immutable SOURCE_GAUGE_CONTROLLER_HASH;

    constructor(address _oracle, bytes32 _sourceGaugeControllerHash) {
        ORACLE = _oracle;
        SOURCE_GAUGE_CONTROLLER_HASH = _sourceGaugeControllerHash;
    }
}
