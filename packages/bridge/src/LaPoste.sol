// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// @title La Poste
/// @notice Main entry point to send/receive messages between EVM chains.
/// @dev The goal is to send pigeons (messages) accross many messaging services (bridges) to the destination chain,
/// and have a required number of messages received to guarantee the correct delivery and execution of the message.
/// @custom:contact contact@stakedao.org
contract LaPoste {
    /// @notice Struct to represent a message to be sent between chains.
    struct Pigeon {
        uint32 originChainId;
        uint32 destinationChainId;
        address receiver;
        bytes message;
    }
}
