// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "@solady/src/utils/Multicallable.sol";

/// Project Interfaces & Libraries
import "src/VM.sol";
import "src/RLPVerifier.sol";

/// @notice A multicall wrapper for the VM and Verifier contracts to help with batch operations.
contract VMMulticall is VM, RLPVerifier, Multicallable {}
