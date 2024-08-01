// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@utils/StateProofVerifier.sol";
import "@solady/src/utils/LibString.sol";

/// @notice Verify RLP proofs, and insert the data into oracle.
contract RLPVerifier {
    using RLPReader for bytes;
    using RLPReader for RLPReader.RLPItem;
    using LibString for address;
    using LibString for string;
}
