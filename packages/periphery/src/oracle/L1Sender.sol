// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/ILaPoste.sol";

/// @notice A module for sending the block hash to the L1 block oracle updater.
contract L1Sender {
    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The L1 block oracle address.
    address public immutable L1_BLOCK_ORACLE_UPDATER;

    /// @notice The error thrown when the block hash is sent too soon.
    error TooSoon();

    constructor(address _l1BlockOracleUpdater, address _laPoste) {
        LA_POSTE = _laPoste;
        L1_BLOCK_ORACLE_UPDATER = _l1BlockOracleUpdater;
    }

    /// @notice Sends the block hash to all contracts on all chains
    /// @dev Requires payment to cover gas fees and checks for timing to avoid too frequent updates
    function broadcastBlock(uint256 chainId, uint256 additionalGasLimit) external payable {
        if (block.timestamp < currentPeriod() + 5 minutes) revert TooSoon();

        bytes memory payload = abi.encode(block.number - 1, blockhash(block.number - 1), block.timestamp);

        ILaPoste.MessageParams memory params = ILaPoste.MessageParams({
            destinationChainId: chainId,
            to: L1_BLOCK_ORACLE_UPDATER,
            token: ILaPoste.Token({tokenAddress: address(0), amount: 0}),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(params, additionalGasLimit);
    }

    function currentPeriod() internal view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }
}
