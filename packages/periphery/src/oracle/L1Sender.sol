// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/ILaPoste.sol";
import "@solady/src/auth/Ownable.sol";

/// @notice A module for sending the block hash to the L1 block oracle updater on L2.
contract L1Sender is Ownable {
    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The L1 block oracle address.
    address public L1_BLOCK_ORACLE_UPDATER;

    /// @notice The error thrown when the block hash is sent too soon.
    error TooSoon();

    constructor(address _laPoste, address _owner) {
        LA_POSTE = _laPoste;

        _initializeOwner(_owner);
    }

    /// @notice Sends the block hash to the L1 block oracle updater.
    function broadcastBlock(uint256 chainId, uint256 additionalGasLimit) external payable {
        if (block.timestamp < currentPeriod() + 1 minutes) revert TooSoon();

        bytes memory payload = abi.encode(block.number - 1, blockhash(block.number - 1), block.timestamp);

        ILaPoste.MessageParams memory params = ILaPoste.MessageParams({
            destinationChainId: chainId,
            to: L1_BLOCK_ORACLE_UPDATER,
            token: ILaPoste.Token({tokenAddress: address(0), amount: 0}),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(params, additionalGasLimit, msg.sender);
    }

    function setL1BlockOracleUpdater(address _l1BlockOracleUpdater) external onlyOwner {
        L1_BLOCK_ORACLE_UPDATER = _l1BlockOracleUpdater;

        _setOwner(address(0));
    }

    function currentPeriod() internal view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }
}
