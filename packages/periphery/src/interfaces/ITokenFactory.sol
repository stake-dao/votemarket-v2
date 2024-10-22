// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

interface ITokenFactory {
    function isWrapped(address token) external view returns (bool);
    function nativeTokens(address token) external view returns (address);
    function wrappedTokens(address token) external view returns (address);
}
