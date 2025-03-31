// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";

import "src/remote/Remote.sol";
import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

/// @notice A module for creating and managing campaigns from L1.
contract VMGovernanceHub is Remote, Ownable {
    using SafeTransferLib for address;

    ////////////////////////////////////////////////////////////////
    /// --- STATE VARIABLES
    ///////////////////////////////////////////////////////////////

    enum ActionType {
        SET_IS_PROTECTED,
        SET_REMOTE,
        SET_FEE,
        SET_CUSTOM_FEE,
        SET_RECIPIENT,
        SET_FEE_COLLECTOR,
        TRANSFER_GOVERNANCE,
        ACCEPT_GOVERNANCE
    }

    struct Payload {
        ActionType actionType;
        bytes parameters;
    }

    /// @notice The list of votemarkets.
    address[] public votemarkets;

    /// @notice The list of destination chain ids.
    uint256[] public destinationChainIds;

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    constructor(address _laPoste, address _tokenFactory, address _owner) Remote(_laPoste, _tokenFactory) {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////
    /// --- L1 SIDE: SETTING FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Sets the is protected status for a list of accounts.
    /// @param _accounts The accounts to set the is protected status for.
    /// @param _isProtected The is protected status.
    /// @param additionalGasLimit The additional gas limit.
    function setIsProtected(address[] memory _accounts, bool _isProtected, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
    {
        bytes memory parameters = abi.encode(_accounts, _isProtected);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_IS_PROTECTED, parameters: parameters}));
        for (uint256 i = 0; i < destinationChainIds.length; i++) {
            _sendMessage({
                destinationChainId: destinationChainIds[i],
                payload: payload,
                tokens: new address[](0),
                amounts: new uint256[](0),
                additionalGasLimit: additionalGasLimit
            });
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- L2 SIDE: RECEIVE MESSAGE
    ///////////////////////////////////////////////////////////////

    /// @notice Receives a message from La Poste.
    /// @param chainId The chain id
    /// @param sender The sender address
    /// @param payload The payload
    /// @dev Handle the cases of creating and managing campaigns. It makes sure that the sender is the manager of the
    /// campaign and that the chain id is valid.
    function receiveMessage(uint256 chainId, address sender, bytes calldata payload) external override onlyLaPoste {
        if (chainId != 1) revert InvalidChainId();
        if (sender != address(this)) revert InvalidSender();

        Payload memory _payload = abi.decode(payload, (Payload));

        if (_payload.actionType == ActionType.SET_IS_PROTECTED) {
            (address[] memory _accounts, bool _isProtected) = abi.decode(_payload.parameters, (address[], bool));
            for (uint256 i = 0; i < _accounts.length; i++) {
                for (uint256 j = 0; j < votemarkets.length; j++) {
                    IVotemarket(votemarkets[j]).setIsProtected(_accounts[i], _isProtected);
                }
            }
        } else if (_payload.actionType == ActionType.SET_REMOTE) {
            address _remote = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).setRemote(_remote);
            }
        } else if (_payload.actionType == ActionType.SET_FEE) {
            uint256 _fee = abi.decode(_payload.parameters, (uint256));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).setFee(_fee);
            }
        } else if (_payload.actionType == ActionType.SET_CUSTOM_FEE) {
            (address[] memory _accounts, uint256[] memory _fees) =
                abi.decode(_payload.parameters, (address[], uint256[]));
            for (uint256 i = 0; i < _accounts.length; i++) {
                for (uint256 j = 0; j < votemarkets.length; j++) {
                    IVotemarket(votemarkets[j]).setCustomFee(_accounts[i], _fees[i]);
                }
            }
        } else if (_payload.actionType == ActionType.SET_RECIPIENT) {
            (address[] memory _accounts, address _recipient) = abi.decode(_payload.parameters, (address[], address));
            for (uint256 i = 0; i < _accounts.length; i++) {
                for (uint256 j = 0; j < votemarkets.length; j++) {
                    IVotemarket(votemarkets[j]).setRecipient(_accounts[i], _recipient);
                }
            }
        } else if (_payload.actionType == ActionType.SET_FEE_COLLECTOR) {
            address _feeCollector = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).setFeeCollector(_feeCollector);
            }
        } else if (_payload.actionType == ActionType.TRANSFER_GOVERNANCE) {
            address _futureGovernance = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).transferGovernance(_futureGovernance);
            }
        } else if (_payload.actionType == ActionType.ACCEPT_GOVERNANCE) {
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).acceptGovernance();
            }
        }
    }
}
