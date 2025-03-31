// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

/// @notice A module for sending and receiving messages from La Poste.
contract Remote {
    using SafeTransferLib for address;

    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The token factory address.
    address public immutable TOKEN_FACTORY;

    /// @notice The error thrown when the sender is not the La Poste address.
    error NotLaPoste();

    /// @notice The error thrown when the sender is invalid.
    error InvalidSender();

    /// @notice The error thrown when the chain id is invalid.
    error InvalidChainId();

    /// @notice The error thrown when the array length mismatch.
    error ArrayLengthMismatch();

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    constructor(address _laPoste, address _tokenFactory) {
        LA_POSTE = _laPoste;
        TOKEN_FACTORY = _tokenFactory;
    }

    /// @notice Sends a message to La Poste.
    /// @param destinationChainId The destination chain id
    /// @param payload The payload
    /// @param tokens The tokens
    /// @param amounts The amounts
    /// @param additionalGasLimit The additional gas limit
    function _sendMessage(
        uint256 destinationChainId,
        bytes memory payload,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 additionalGasLimit
    ) internal {
        if (tokens.length != amounts.length) revert ArrayLengthMismatch();

        ILaPoste.Token[] memory pTokens = new ILaPoste.Token[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            SafeTransferLib.safeTransferFrom({token: tokens[i], from: msg.sender, to: address(this), amount: amounts[i]});

            pTokens[i] = ILaPoste.Token({tokenAddress: tokens[i], amount: amounts[i]});
        }

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            tokens: pTokens,
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);
    }

    /// @notice Receives a message from La Poste.
    /// @param chainId The chain id
    /// @param sender The sender address
    /// @dev Handle the cases of creating and managing campaigns. It makes sure that the sender is the manager of the
    /// campaign and that the chain id is valid.
    function receiveMessage(uint256 chainId, address sender, bytes calldata) external virtual onlyLaPoste {
        if (chainId != 1) revert InvalidChainId();
        if (sender != address(this)) revert InvalidSender();
    }
}
