// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

abstract contract Bridge {
    address public immutable LA_POSTE;

    address public immutable TOKEN_FACTORY;

    constructor(address _laPoste) {
        LA_POSTE = _laPoste;
        TOKEN_FACTORY = ILaPoste(_laPoste).tokenFactory();
    }

    function bridge(address token, uint256 amount, uint256 destinationChainId, address receiver) external payable {
        address wrappedToken = ITokenFactory(TOKEN_FACTORY).wrappedTokens(token);

        SafeTransferLib.safeTransferFrom(wrappedToken, msg.sender, address(this), amount);

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: receiver,
            token: ILaPoste.Token({tokenAddress: token, amount: amount}),
            payload: ""
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, 0, msg.sender);
    }
}
