// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

abstract contract Bridge {
    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The token factory address.
    address public immutable TOKEN_FACTORY;

    constructor(address _laPoste) {
        LA_POSTE = _laPoste;
        TOKEN_FACTORY = ILaPoste(_laPoste).tokenFactory();
    }

    /// @notice Bridges the given token to the given chain.
    /// @param tokens The tokens to bridge.
    /// @param amounts The amounts of tokens to bridge.
    /// @param destinationChainId The chain ID to bridge the token to.
    /// @param receiver The receiver of the token.
    /// @dev The token address should be the official token address available on L1. The TokenFactory will retrieve the wrapped token address,
    /// transfer it, and burn it.
    /// The flow should be:
    /// 1. Approve the wrapped token to be spent by this contract.
    /// 2. Call this function, but using the original token address.
    /// 3. Wrapped token is transferred to this contract.
    /// 4. Wrapped token is burned from this contract.
    /// 5. Message is sent to the destination chain.
    /// 6. The receiver on the destination chain receives the unlocked original tokens.
    function bridge(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address receiver
    ) external payable {
        ILaPoste.Token[] memory laPosteTokens = new ILaPoste.Token[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            address wrappedToken = ITokenFactory(TOKEN_FACTORY).wrappedTokens(tokens[i]);
            SafeTransferLib.safeTransferFrom(wrappedToken, msg.sender, address(this), amounts[i]);

            laPosteTokens[i] = ILaPoste.Token({tokenAddress: tokens[i], amount: amounts[i]});
        }

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: receiver,
            tokens: laPosteTokens,
            payload: ""
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);
    }
}
