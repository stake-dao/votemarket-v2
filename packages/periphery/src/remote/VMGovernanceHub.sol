// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Ownable} from "@solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "@solady/src/utils/SafeTransferLib.sol";
import {IVotemarket} from "@votemarket/src/interfaces/IVotemarket.sol";
import {IOracle} from "@votemarket/src/interfaces/IOracle.sol";
import {Remote} from "src/remote/Remote.sol";

/// @notice A module for creating and managing campaigns from L1.
contract VMGovernanceHub is Remote, Ownable {
    using SafeTransferLib for address;

    /// @notice The error thrown when the payload is invalid.
    error InvalidPayload();

    ////////////////////////////////////////////////////////////////
    /// --- STATE VARIABLES
    ///////////////////////////////////////////////////////////////

    enum ActionType {
        /// Votemarket Functions.
        SET_IS_PROTECTED,
        SET_REMOTE,
        SET_FEE,
        SET_CUSTOM_FEE,
        SET_RECIPIENT,
        SET_FEE_COLLECTOR,
        TRANSFER_VOTEMARKET_GOVERNANCE,
        ACCEPT_VOTEMARKET_GOVERNANCE,
        /// Oracle Functions.
        SET_AUTHORIZED_BLOCK_NUMBER_PROVIDER,
        REVOKE_AUTHORIZED_BLOCK_NUMBER_PROVIDER,
        SET_AUTHORIZED_DATA_PROVIDER,
        REVOKE_AUTHORIZED_DATA_PROVIDER,
        TRANSFER_ORACLE_GOVERNANCE,
        ACCEPT_ORACLE_GOVERNANCE,
        /// Configuration.
        ADD_ORACLE,
        ADD_VOTEMARKET,
        ADD_DESTINATION_CHAIN_ID
    }

    struct Payload {
        ActionType actionType;
        bytes parameters;
    }

    /// @notice The list of votemarkets.
    address[] public votemarkets;

    /// @notice The list of oracles.
    address[] public oracles;

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    constructor(address _laPoste, address _tokenFactory, address _owner) Remote(_laPoste, _tokenFactory) {
        _initializeOwner(_owner);
    }

    ////////////////////////////////////////////////////////////////
    /// --- L1 SIDE: VOTEMARKET FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Sets the is protected status for a list of accounts.
    /// @param _votemarket The votemarket address.
    /// @param _accounts The accounts to set the is protected status for.
    /// @param _isProtected The is protected status.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setIsProtected(
        address _votemarket,
        address[] calldata _accounts,
        bool _isProtected,
        uint256 additionalGasLimit
    ) external payable onlyValidChainId onlyOwner {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _isProtected);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_IS_PROTECTED, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the remote address.
    /// @param _remote The remote address.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setRemote(address _remote, uint256 additionalGasLimit) external payable onlyOwner onlyValidChainId {
        bytes memory parameters = abi.encode(_remote);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_REMOTE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the fee.
    /// @param _fee The fee.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setFee(uint256 _fee, uint256 additionalGasLimit) external payable onlyOwner onlyValidChainId {
        bytes memory parameters = abi.encode(_fee);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_FEE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the custom fee for a list of accounts.
    /// @param _votemarket The votemarket address.
    /// @param _accounts The accounts to set the custom fee for.
    /// @param _fees The custom fees.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setCustomFee(
        address _votemarket,
        address[] calldata _accounts,
        uint256[] calldata _fees,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _fees);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_CUSTOM_FEE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the recipient for a list of accounts.
    /// @param _accounts The accounts to set the recipient for.
    /// @param _recipient The recipient.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setRecipient(
        address _votemarket,
        address[] calldata _accounts,
        address _recipient,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _recipient);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_RECIPIENT, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the fee collector.
    /// @param _feeCollector The fee collector.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setFeeCollector(address _feeCollector, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_feeCollector);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_FEE_COLLECTOR, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Transfers the governance role to a new owner.
    /// @param _futureGovernance The new owner.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function transferVotemarketGovernance(address _futureGovernance, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_futureGovernance);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.TRANSFER_VOTEMARKET_GOVERNANCE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function acceptVotemarketGovernance(uint256 additionalGasLimit) external payable onlyOwner onlyValidChainId {
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ACCEPT_VOTEMARKET_GOVERNANCE, parameters: new bytes(0)}));

        _dispatch(payload, additionalGasLimit);
    }

    ////////////////////////////////////////////////////////////////
    /// --- L1 SIDE: ORACLE FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Sets the authorized block number provider.
    /// @param _blockNumberProvider The block number provider.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setAuthorizedBlockNumberProvider(address _oracle, address _blockNumberProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_oracle, _blockNumberProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.SET_AUTHORIZED_BLOCK_NUMBER_PROVIDER, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Revokes the authorized block number provider.
    /// @param _oracle The oracle.
    /// @param _blockNumberProvider The block number provider.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function revokeAuthorizedBlockNumberProvider(
        address _oracle,
        address _blockNumberProvider,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId {
        bytes memory parameters = abi.encode(_oracle, _blockNumberProvider);
        bytes memory payload = abi.encode(
            Payload({actionType: ActionType.REVOKE_AUTHORIZED_BLOCK_NUMBER_PROVIDER, parameters: parameters})
        );

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the authorized data provider.
    /// @param _oracle The oracle.
    /// @param _dataProvider The data provider.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setAuthorizedDataProvider(address _oracle, address _dataProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_oracle, _dataProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.SET_AUTHORIZED_DATA_PROVIDER, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Revokes the authorized data provider.
    /// @param _oracle The oracle.
    /// @param _dataProvider The data provider.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function revokeAuthorizedDataProvider(address _oracle, address _dataProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_oracle, _dataProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.REVOKE_AUTHORIZED_DATA_PROVIDER, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Transfers the governance role to a new owner.
    /// @param _futureGovernance The new owner.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function transferOracleGovernance(address _futureGovernance, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        bytes memory parameters = abi.encode(_futureGovernance);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.TRANSFER_ORACLE_GOVERNANCE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function acceptOracleGovernance(uint256 additionalGasLimit) external payable onlyOwner onlyValidChainId {
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ACCEPT_ORACLE_GOVERNANCE, parameters: new bytes(0)}));
        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Adds a votemarket.
    /// @param _votemarkets The votemarkets.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setVotemarkets(address[] calldata _votemarkets, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        /// 1. Update L1.
        votemarkets = _votemarkets;

        /// 2. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_votemarkets);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.ADD_VOTEMARKET, parameters: parameters}));

        /// 3. Dispatch messages to L2 to synchronize state.
        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Adds an oracle.
    /// @param _oracles The oracles.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setOracles(address[] calldata _oracles, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        /// 1. Update L1.
        oracles = _oracles;

        /// 3. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_oracles);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.ADD_ORACLE, parameters: parameters}));

        /// 3. Dispatch messages to L2 to synchronize state.
        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Adds destination chain ids.
    /// @param _destinationChainIds The destination chain ids.
    /// @param additionalGasLimit The additional gas limit.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function setDestinationChainIds(uint256[] calldata _destinationChainIds, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId
    {
        /// 1. Update L1.
        destinationChainIds = _destinationChainIds;

        /// 2. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_destinationChainIds);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ADD_DESTINATION_CHAIN_ID, parameters: parameters}));

        /// 3. Dispatch messages to L2 to synchronize state.
        _dispatch(payload, additionalGasLimit);
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
            _handleSetIsProtected(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_REMOTE) {
            _handleSetRemote(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_FEE) {
            _handleSetFee(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_CUSTOM_FEE) {
            _handleSetCustomFee(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_RECIPIENT) {
            _handleSetRecipient(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_FEE_COLLECTOR) {
            _handleSetFeeCollector(_payload.parameters);
        } else if (_payload.actionType == ActionType.TRANSFER_VOTEMARKET_GOVERNANCE) {
            _handleTransferGovernance(_payload.parameters, votemarkets);
        } else if (_payload.actionType == ActionType.ACCEPT_VOTEMARKET_GOVERNANCE) {
            _handleAcceptGovernance(_payload.parameters, votemarkets);
        } else if (_payload.actionType == ActionType.SET_AUTHORIZED_BLOCK_NUMBER_PROVIDER) {
            _handleSetAuthorizedBlockNumberProvider(_payload.parameters);
        } else if (_payload.actionType == ActionType.REVOKE_AUTHORIZED_BLOCK_NUMBER_PROVIDER) {
            _handleRevokeAuthorizedBlockNumberProvider(_payload.parameters);
        } else if (_payload.actionType == ActionType.SET_AUTHORIZED_DATA_PROVIDER) {
            _handleSetAuthorizedDataProvider(_payload.parameters);
        } else if (_payload.actionType == ActionType.REVOKE_AUTHORIZED_DATA_PROVIDER) {
            _handleRevokeAuthorizedDataProvider(_payload.parameters);
        } else if (_payload.actionType == ActionType.TRANSFER_ORACLE_GOVERNANCE) {
            _handleTransferGovernance(_payload.parameters, oracles);
        } else if (_payload.actionType == ActionType.ACCEPT_ORACLE_GOVERNANCE) {
            _handleAcceptGovernance(_payload.parameters, oracles);
        } else if (_payload.actionType == ActionType.ADD_VOTEMARKET) {
            _handleAddVotemarket(_payload.parameters);
        } else if (_payload.actionType == ActionType.ADD_ORACLE) {
            _handleAddOracle(_payload.parameters);
        } else if (_payload.actionType == ActionType.ADD_DESTINATION_CHAIN_ID) {
            _handleAddDestinationChainId(_payload.parameters);
        } else {
            revert InvalidPayload();
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- MESSAGE HANDLER
    ///////////////////////////////////////////////////////////////

    function _dispatch(bytes memory payload, uint256 additionalGasLimit) internal {
        _sendMessage({
            payload: payload,
            tokens: new address[](0),
            amounts: new uint256[](0),
            additionalGasLimit: additionalGasLimit
        });
    }

    ////////////////////////////////////////////////////////////////
    /// --- ACTIONS HANDLER
    ///////////////////////////////////////////////////////////////

    function _handleSetIsProtected(bytes memory parameters) internal {
        (address _votemarket, address[] memory _accounts, bool _isProtected) =
            abi.decode(parameters, (address, address[], bool));

        uint256 accountLength = _accounts.length;
        for (uint256 i; i < accountLength;) {
            IVotemarket(_votemarket).setIsProtected(_accounts[i], _isProtected);
            unchecked {
                i++;
            }
        }
    }

    function _handleSetRemote(bytes memory parameters) internal {
        address _remote = abi.decode(parameters, (address));
        uint256 votemarketLength = votemarkets.length;

        for (uint256 i; i < votemarketLength;) {
            IVotemarket(votemarkets[i]).setRemote(_remote);
            unchecked {
                i++;
            }
        }
    }

    function _handleSetFee(bytes memory parameters) internal {
        uint256 _fee = abi.decode(parameters, (uint256));
        uint256 votemarketLength = votemarkets.length;

        for (uint256 i; i < votemarketLength;) {
            IVotemarket(votemarkets[i]).setFee(_fee);
            unchecked {
                i++;
            }
        }
    }

    function _handleSetCustomFee(bytes memory parameters) internal {
        (address votemarket, address[] memory _accounts, uint256[] memory _fees) =
            abi.decode(parameters, (address, address[], uint256[]));
        uint256 accountLength = _accounts.length;

        for (uint256 i; i < accountLength;) {
            IVotemarket(votemarket).setCustomFee(_accounts[i], _fees[i]);
            unchecked {
                i++;
            }
        }
    }

    function _handleSetRecipient(bytes memory parameters) internal {
        (address votemarket, address[] memory _accounts, address _recipient) =
            abi.decode(parameters, (address, address[], address));
        uint256 accountLength = _accounts.length;

        for (uint256 i; i < accountLength;) {
            IVotemarket(votemarket).setRecipient(_accounts[i], _recipient);
            unchecked {
                i++;
            }
        }
    }

    function _handleSetFeeCollector(bytes memory parameters) internal {
        (address _feeCollector) = abi.decode(parameters, (address));
        uint256 votemarketLength = votemarkets.length;

        for (uint256 i; i < votemarketLength;) {
            IVotemarket(votemarkets[i]).setFeeCollector(_feeCollector);
            unchecked {
                i++;
            }
        }
    }

    function _handleTransferGovernance(bytes memory parameters, address[] memory _entities) internal {
        address _futureGovernance = abi.decode(parameters, (address));
        uint256 entityLength = _entities.length;

        for (uint256 i; i < entityLength;) {
            IOracle(_entities[i]).transferGovernance(_futureGovernance);
            unchecked {
                i++;
            }
        }
    }

    function _handleAcceptGovernance(bytes memory, address[] memory _entities) internal {
        uint256 entityLength = _entities.length;

        for (uint256 i; i < entityLength;) {
            IOracle(_entities[i]).acceptGovernance();
            unchecked {
                i++;
            }
        }
    }

    function _handleAddVotemarket(bytes memory parameters) internal {
        votemarkets = abi.decode(parameters, (address[]));
    }

    function _handleAddOracle(bytes memory parameters) internal {
        oracles = abi.decode(parameters, (address[]));
    }

    function _handleAddDestinationChainId(bytes memory parameters) internal {
        destinationChainIds = abi.decode(parameters, (uint256[]));
    }

    function _handleSetAuthorizedBlockNumberProvider(bytes memory parameters) internal {
        (address _oracle, address _blockNumberProvider) = abi.decode(parameters, (address, address));
        IOracle(_oracle).setAuthorizedBlockNumberProvider(_blockNumberProvider);
    }

    function _handleRevokeAuthorizedBlockNumberProvider(bytes memory parameters) internal {
        (address _oracle, address _blockNumberProvider) = abi.decode(parameters, (address, address));
        IOracle(_oracle).revokeAuthorizedBlockNumberProvider(_blockNumberProvider);
    }

    function _handleSetAuthorizedDataProvider(bytes memory parameters) internal {
        (address _oracle, address _dataProvider) = abi.decode(parameters, (address, address));
        IOracle(_oracle).setAuthorizedDataProvider(_dataProvider);
    }

    function _handleRevokeAuthorizedDataProvider(bytes memory parameters) internal {
        (address _oracle, address _dataProvider) = abi.decode(parameters, (address, address));
        IOracle(_oracle).revokeAuthorizedDataProvider(_dataProvider);
    }

    ////////////////////////////////////////////////////////////////
    /// --- UTILS
    ///////////////////////////////////////////////////////////////

    /// @notice Sweeps the sleeping ETH to the receiver.
    /// @param receiver The receiver address.
    /// @dev Contract can hold native tokens due to the division in the `_sendMessage` function.
    /// @custom:throws OwnableUnauthorizedAccount If the caller is not the owner.
    function sweep(address receiver) external onlyOwner {
        SafeTransferLib.safeTransferAllETH(receiver);
    }
}
