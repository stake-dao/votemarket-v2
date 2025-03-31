// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";
import "@votemarket/src/interfaces/IOracle.sol";

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

    /// @notice The list of destination chain ids.
    uint256[] public destinationChainIds;

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
    /// @param _accounts The accounts to set the is protected status for.
    /// @param _isProtected The is protected status.
    /// @param additionalGasLimit The additional gas limit.
    function setIsProtected(
        address _votemarket,
        address[] memory _accounts,
        bool _isProtected,
        uint256 additionalGasLimit
    ) external payable onlyValidChainId(block.chainid) onlyOwner {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _isProtected);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_IS_PROTECTED, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the remote address.
    /// @param _remote The remote address.
    /// @param additionalGasLimit The additional gas limit.
    function setRemote(address _remote, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_remote);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_REMOTE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the fee.
    /// @param _fee The fee.
    /// @param additionalGasLimit The additional gas limit.
    function setFee(uint256 _fee, uint256 additionalGasLimit) external payable onlyOwner {
        bytes memory parameters = abi.encode(_fee);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_FEE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the custom fee for a list of accounts.
    /// @param _accounts The accounts to set the custom fee for.
    /// @param _fees The custom fees.
    /// @param additionalGasLimit The additional gas limit.
    function setCustomFee(
        address _votemarket,
        address[] memory _accounts,
        uint256[] memory _fees,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId(block.chainid) {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _fees);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_CUSTOM_FEE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the recipient for a list of accounts.
    /// @param _accounts The accounts to set the recipient for.
    /// @param _recipient The recipient.
    /// @param additionalGasLimit The additional gas limit.
    function setRecipient(
        address _votemarket,
        address[] memory _accounts,
        address _recipient,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId(block.chainid) {
        bytes memory parameters = abi.encode(_votemarket, _accounts, _recipient);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_RECIPIENT, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Sets the fee collector.
    /// @param _feeCollector The fee collector.
    /// @param additionalGasLimit The additional gas limit.
    function setFeeCollector(address _feeCollector, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_feeCollector);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_FEE_COLLECTOR, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Transfers the governance role to a new owner.
    /// @param _futureGovernance The new owner.
    /// @param additionalGasLimit The additional gas limit.
    function transferVotemarketGovernance(address _futureGovernance, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_futureGovernance);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.TRANSFER_VOTEMARKET_GOVERNANCE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    function acceptVotemarketGovernance(uint256 additionalGasLimit) external payable onlyOwner {
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
    function setAuthorizedBlockNumberProvider(address _oracle, address _blockNumberProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
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
    function revokeAuthorizedBlockNumberProvider(
        address _oracle,
        address _blockNumberProvider,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId(block.chainid) {
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
    function setAuthorizedDataProvider(address _oracle, address _dataProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
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
    function revokeAuthorizedDataProvider(address _oracle, address _dataProvider, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_oracle, _dataProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.REVOKE_AUTHORIZED_DATA_PROVIDER, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Transfers the governance role to a new owner.
    /// @param _futureGovernance The new owner.
    /// @param additionalGasLimit The additional gas limit.
    function transferOracleGovernance(address _futureGovernance, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_futureGovernance);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.TRANSFER_ORACLE_GOVERNANCE, parameters: parameters}));

        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    function acceptOracleGovernance(uint256 additionalGasLimit) external payable onlyOwner {
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ACCEPT_ORACLE_GOVERNANCE, parameters: new bytes(0)}));
        _dispatch(payload, additionalGasLimit);
    }

    /// @notice Adds a votemarket.
    /// @param _votemarkets The votemarkets.
    /// @param additionalGasLimit The additional gas limit.
    function setVotemarkets(address[] memory _votemarkets, uint256 additionalGasLimit) external payable onlyOwner {
        /// 1. Update L1.
        delete votemarkets;
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
    function setOracles(address[] memory _oracles, uint256 additionalGasLimit) external payable onlyOwner {
        /// 1. Update L1.
        delete oracles;
        oracles = _oracles;

        /// 3. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_oracles);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.ADD_ORACLE, parameters: parameters}));

        /// 3. Dispatch messages to L2 to synchronize state.
        _dispatch(payload, additionalGasLimit);
    }

    function setDestinationChainIds(uint256[] memory _destinationChainIds, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
    {
        /// 1. Update L1.
        delete destinationChainIds;
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
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- MESSAGE HANDLER
    ///////////////////////////////////////////////////////////////

    function _dispatch(bytes memory payload, uint256 additionalGasLimit) internal {
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
    /// --- ACTIONS HANDLER
    ///////////////////////////////////////////////////////////////

    function _handleSetIsProtected(bytes memory parameters) internal {
        (address _votemarket, address[] memory _accounts, bool _isProtected) =
            abi.decode(parameters, (address, address[], bool));

        for (uint256 i = 0; i < _accounts.length; i++) {
            IVotemarket(_votemarket).setIsProtected(_accounts[i], _isProtected);
        }
    }

    function _handleSetRemote(bytes memory parameters) internal {
        address _remote = abi.decode(parameters, (address));
        for (uint256 i = 0; i < votemarkets.length; i++) {
            IVotemarket(votemarkets[i]).setRemote(_remote);
        }
    }

    function _handleSetFee(bytes memory parameters) internal {
        uint256 _fee = abi.decode(parameters, (uint256));
        for (uint256 i = 0; i < votemarkets.length; i++) {
            IVotemarket(votemarkets[i]).setFee(_fee);
        }
    }

    function _handleSetCustomFee(bytes memory parameters) internal {
        (address votemarket, address[] memory _accounts, uint256[] memory _fees) =
            abi.decode(parameters, (address, address[], uint256[]));
        for (uint256 i = 0; i < _accounts.length; i++) {
            IVotemarket(votemarket).setCustomFee(_accounts[i], _fees[i]);
        }
    }

    function _handleSetRecipient(bytes memory parameters) internal {
        (address votemarket, address[] memory _accounts, address _recipient) =
            abi.decode(parameters, (address, address[], address));
        for (uint256 i = 0; i < _accounts.length; i++) {
            IVotemarket(votemarket).setRecipient(_accounts[i], _recipient);
        }
    }

    function _handleSetFeeCollector(bytes memory parameters) internal {
        (address _feeCollector) = abi.decode(parameters, (address));
        for (uint256 i = 0; i < votemarkets.length; i++) {
            IVotemarket(votemarkets[i]).setFeeCollector(_feeCollector);
        }
    }

    function _handleTransferGovernance(bytes memory parameters, address[] memory _entities) internal {
        address _futureGovernance = abi.decode(parameters, (address));
        for (uint256 i = 0; i < _entities.length; i++) {
            IOracle(_entities[i]).transferGovernance(_futureGovernance);
        }
    }

    function _handleAcceptGovernance(bytes memory parameters, address[] memory _entities) internal {
        for (uint256 i = 0; i < _entities.length; i++) {
            IOracle(_entities[i]).acceptGovernance();
        }
    }

    function _handleAddVotemarket(bytes memory parameters) internal {
        address[] memory _votemarkets = abi.decode(parameters, (address[]));
        delete votemarkets;
        votemarkets = _votemarkets;
    }

    function _handleAddOracle(bytes memory parameters) internal {
        address[] memory _oracles = abi.decode(parameters, (address[]));
        delete oracles;
        oracles = _oracles;
    }

    function _handleAddDestinationChainId(bytes memory parameters) internal {
        uint256[] memory _destinationChainIds = abi.decode(parameters, (uint256[]));
        delete destinationChainIds;
        destinationChainIds = _destinationChainIds;
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
}