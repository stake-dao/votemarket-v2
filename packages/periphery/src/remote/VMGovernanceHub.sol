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

    /// @notice Is the address an oracle?
    mapping(address => bool) public isOracle;

    /// @notice Is the address a votemarket?
    mapping(address => bool) public isVotemarket;

    /// @notice The list of destination chain ids.
    uint256[] public destinationChainIds;

    /// @notice The error for an invalid address.
    error InvalidAddress();

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

    /// @notice Sets the fee.
    /// @param _fee The fee.
    /// @param additionalGasLimit The additional gas limit.
    function setFee(uint256 _fee, uint256 additionalGasLimit) external payable onlyOwner {
        bytes memory parameters = abi.encode(_fee);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_FEE, parameters: parameters}));
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

    /// @notice Sets the custom fee for a list of accounts.
    /// @param _accounts The accounts to set the custom fee for.
    /// @param _fees The custom fees.
    /// @param additionalGasLimit The additional gas limit.
    function setCustomFee(address[] memory _accounts, uint256[] memory _fees, uint256 additionalGasLimit)
        external
        payable
        onlyOwner
        onlyValidChainId(block.chainid)
    {
        bytes memory parameters = abi.encode(_accounts, _fees);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_CUSTOM_FEE, parameters: parameters}));
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
        if (!isVotemarket[_votemarket]) revert InvalidAddress();

        bytes memory parameters = abi.encode(_votemarket, _accounts, _recipient);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.SET_RECIPIENT, parameters: parameters}));
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

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    function acceptVotemarketGovernance(uint256 additionalGasLimit) external payable onlyOwner {
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ACCEPT_VOTEMARKET_GOVERNANCE, parameters: new bytes(0)}));
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
        if (!isOracle[_oracle]) revert InvalidAddress();

        bytes memory parameters = abi.encode(_oracle, _blockNumberProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.SET_AUTHORIZED_BLOCK_NUMBER_PROVIDER, parameters: parameters}));
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

    /// @notice Revokes the authorized block number provider.
    /// @param _oracle The oracle.
    /// @param _blockNumberProvider The block number provider.
    /// @param additionalGasLimit The additional gas limit.
    function revokeAuthorizedBlockNumberProvider(
        address _oracle,
        address _blockNumberProvider,
        uint256 additionalGasLimit
    ) external payable onlyOwner onlyValidChainId(block.chainid) {
        if (!isOracle[_oracle]) revert InvalidAddress();

        bytes memory parameters = abi.encode(_oracle, _blockNumberProvider);
        bytes memory payload = abi.encode(
            Payload({actionType: ActionType.REVOKE_AUTHORIZED_BLOCK_NUMBER_PROVIDER, parameters: parameters})
        );
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
        if (!isOracle[_oracle]) revert InvalidAddress();

        bytes memory parameters = abi.encode(_oracle, _dataProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.SET_AUTHORIZED_DATA_PROVIDER, parameters: parameters}));
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
        if (!isOracle[_oracle]) revert InvalidAddress();

        bytes memory parameters = abi.encode(_oracle, _dataProvider);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.REVOKE_AUTHORIZED_DATA_PROVIDER, parameters: parameters}));
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

    /// @notice Accepts the governance role.
    /// @param additionalGasLimit The additional gas limit.
    function acceptOracleGovernance(uint256 additionalGasLimit) external payable onlyOwner {
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.ACCEPT_ORACLE_GOVERNANCE, parameters: new bytes(0)}));
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

    /// @notice Adds a votemarket.
    /// @param _votemarkets The votemarkets.
    /// @param additionalGasLimit The additional gas limit.
    function setVotemarkets(address[] memory _votemarkets, uint256 additionalGasLimit) external payable onlyOwner {
        /// 1. Update L1.
        delete votemarkets;
        votemarkets = _votemarkets;

        /// 2. Update mapping.
        for (uint256 i = 0; i < _votemarkets.length; i++) {
            isVotemarket[_votemarkets[i]] = true;
        }

        /// 3. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_votemarkets);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.ADD_VOTEMARKET, parameters: parameters}));
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

    /// @notice Adds an oracle.
    /// @param _oracles The oracles.
    /// @param additionalGasLimit The additional gas limit.
    function setOracles(address[] memory _oracles, uint256 additionalGasLimit) external payable onlyOwner {
        /// 1. Update L1.
        delete oracles;
        oracles = _oracles;

        /// 2. Update mapping.
        for (uint256 i = 0; i < _oracles.length; i++) {
            isOracle[_oracles[i]] = true;
        }

        /// 3. Send messages to L2 to synchronize state.
        bytes memory parameters = abi.encode(_oracles);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.ADD_ORACLE, parameters: parameters}));
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
            (address _votemarket, address[] memory _accounts, bool _isProtected) =
                abi.decode(_payload.parameters, (address, address[], bool));
            for (uint256 i = 0; i < _accounts.length; i++) {
                IVotemarket(_votemarket).setIsProtected(_accounts[i], _isProtected);
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
            (address votemarket, address[] memory _accounts, address _recipient) =
                abi.decode(_payload.parameters, (address, address[], address));
            for (uint256 i = 0; i < _accounts.length; i++) {
                IVotemarket(votemarket).setRecipient(_accounts[i], _recipient);
            }
        } else if (_payload.actionType == ActionType.SET_FEE_COLLECTOR) {
            (address _feeCollector) = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).setFeeCollector(_feeCollector);
            }
        } else if (_payload.actionType == ActionType.TRANSFER_VOTEMARKET_GOVERNANCE) {
            address _futureGovernance = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).transferGovernance(_futureGovernance);
            }
        } else if (_payload.actionType == ActionType.ACCEPT_VOTEMARKET_GOVERNANCE) {
            for (uint256 i = 0; i < votemarkets.length; i++) {
                IVotemarket(votemarkets[i]).acceptGovernance();
            }
        } else if (_payload.actionType == ActionType.TRANSFER_ORACLE_GOVERNANCE) {
            address _futureGovernance = abi.decode(_payload.parameters, (address));
            for (uint256 i = 0; i < oracles.length; i++) {
                IOracle(oracles[i]).transferGovernance(_futureGovernance);
            }
        } else if (_payload.actionType == ActionType.ACCEPT_ORACLE_GOVERNANCE) {
            for (uint256 i = 0; i < oracles.length; i++) {
                IOracle(oracles[i]).acceptGovernance();
            }
        } else if (_payload.actionType == ActionType.ADD_VOTEMARKET) {
            address[] memory _votemarkets = abi.decode(_payload.parameters, (address[]));

            delete votemarkets;
            votemarkets = _votemarkets;

            for (uint256 i = 0; i < _votemarkets.length; i++) {
                isVotemarket[_votemarkets[i]] = true;
            }
        } else if (_payload.actionType == ActionType.ADD_ORACLE) {
            address[] memory _oracles = abi.decode(_payload.parameters, (address[]));
            delete oracles;
            oracles = _oracles;

            for (uint256 i = 0; i < _oracles.length; i++) {
                isOracle[_oracles[i]] = true;
            }
        } else if (_payload.actionType == ActionType.ADD_DESTINATION_CHAIN_ID) {
            uint256[] memory _destinationChainIds = abi.decode(_payload.parameters, (uint256[]));
            delete destinationChainIds;
            destinationChainIds = _destinationChainIds;
        }
    }
}
