// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "@solady/src/utils/Multicallable.sol";

/// Project Interfaces & Libraries
import "src/bundler/VM.sol";
import "src/bundler/Bridge.sol";
import "src/bundler/RLPVerifierPendle.sol";

/// @notice A multicall wrapper for the VM and Verifier contracts to help with batch operations.
contract BundlerPendle is VM, RLPVerifierPendle, Multicallable, Bridge {
    constructor(address _laPoste) Bridge(_laPoste) {}

    function multicall(bytes[] calldata data) public payable virtual override returns (bytes[] memory) {
        _multicallDirectReturn(_multicall(data));
    }
}
