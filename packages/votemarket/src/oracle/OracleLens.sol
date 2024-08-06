// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

///  Project Interfaces
import "src/interfaces/IOracle.sol";

/// @notice Oracle Lens contract to read from the Oracle contract and expose data to the Votemarket contract.
contract OracleLens {
    address public immutable oracle;

    constructor(address _oracle) {
        oracle = _oracle;
    }

    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {}
    function canClaim(address account, address gauge, uint256 epoch) external view returns (bool) {}
    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {}
}
