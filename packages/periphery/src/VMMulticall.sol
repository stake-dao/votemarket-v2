// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/Multicallable.sol";

import "src/VM.sol";
import "src/Verifier.sol";

contract VMMulticall is VM, Verifier, Multicallable {}
