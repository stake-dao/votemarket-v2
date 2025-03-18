// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/ILaPoste.sol";
import "@solady/src/auth/Ownable.sol";

/// @notice A module for broadcasting the L1 block data to the L1 block oracle updater on L2.
/// @dev Enforces a claim protection delay: broadcasts can only occur at least 1 hour after the start
/// of the current weekly period.
contract L1Sender is Ownable {
    ////////////////////////////////////////////////////////////////
    /// STATE VARIABLES
    ////////////////////////////////////////////////////////////////

    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The L1 block oracle updater address.
    address public L1_BLOCK_ORACLE_UPDATER;

    ////////////////////////////////////////////////////////////////
    /// ERRORS
    ////////////////////////////////////////////////////////////////

    /// @notice Thrown when attempting to broadcast before the claim protection period has elapsed.
    error TooSoon();

    ////////////////////////////////////////////////////////////////
    /// CONSTRUCTOR
    ////////////////////////////////////////////////////////////////

    /// @notice Initializes the contract with the La Poste address and sets the owner.
    /// @param _laPoste The La Poste address.
    /// @param _owner The address that will become the initial owner.
    constructor(address _laPoste, address _owner) {
        LA_POSTE = _laPoste;
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////
    /// EXTERNAL / PUBLIC FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /// @notice Broadcasts the previous block's data to the L1 block oracle updater on L2.
    /// @param chainId The destination chain ID.
    /// @param additionalGasLimit Additional gas limit for the message dispatch.
    /// @dev Enforces that the broadcast only occurs after the claim protection period (1 hour after the weekly period start).
    function broadcastBlock(uint256 chainId, uint256 additionalGasLimit) external payable {
        // Enforce claim protection delay: broadcasts are only allowed 2 hours after the weekly period starts.
        if (block.timestamp < currentPeriod() + 2 hours) revert TooSoon();

        // Encode the block data (using the previous block)
        bytes memory payload = abi.encode(block.number - 1, blockhash(block.number - 1), block.timestamp);

        ILaPoste.MessageParams memory params = ILaPoste.MessageParams({
            destinationChainId: chainId,
            to: L1_BLOCK_ORACLE_UPDATER,
            tokens: new ILaPoste.Token[](0),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(params, additionalGasLimit, msg.sender);
    }

    /// @notice Sets the L1 block oracle updater address.
    /// @param _l1BlockOracleUpdater The new L1 block oracle updater address.
    /// @dev Only callable by the owner. Once set, the ownership is renounced.
    function setL1BlockOracleUpdater(address _l1BlockOracleUpdater) external onlyOwner {
        L1_BLOCK_ORACLE_UPDATER = _l1BlockOracleUpdater;
        // Renounce ownership after setting the updater.
        _setOwner(address(0));
    }

    ////////////////////////////////////////////////////////////////
    /// INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /// @notice Returns the start of the current weekly period.
    /// @return The timestamp corresponding to the start of the current week.
    function currentPeriod() internal view returns (uint256) {
        return (block.timestamp / 1 weeks) * 1 weeks;
    }
}
