// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IL1Block.sol";
import "src/interfaces/ILaPoste.sol";
import "@votemarket/src/interfaces/IOracle.sol";

/// @notice A module for updating the L1 block number in multiple oracles and dispatching the block hash on L2.
/// It uses the L1_BLOCK_ORACLE as a source of truth. During the window defined by the daily epoch + 1h (UTC),
/// only the governance address can update; after that, anyone can call.
contract L1BlockOracleUpdater {
    ////////////////////////////////////////////////////////////////
    /// STORAGE VARIABLES
    ////////////////////////////////////////////////////////////////

    /// @notice The L1 sender address.
    address public immutable L1_SENDER;
    /// @notice The La Poste address.
    address public immutable LA_POSTE;
    /// @notice The L1 block oracle address used as data source.
    address public immutable L1_BLOCK_ORACLE;

    /// @notice The governance address.
    address public governance;
    /// @notice Future governance address.
    address public futureGovernance;

    /// @notice Array of oracle contracts that will be updated.
    IOracle[] public oracles;

    ////////////////////////////////////////////////////////////////
    /// ERRORS
    ////////////////////////////////////////////////////////////////

    error NotLaPoste();
    error WrongSender();
    error L1BlockOracleNotSet();
    error ZERO_ADDRESS();
    error AUTH_GOVERNANCE_ONLY();

    ////////////////////////////////////////////////////////////////
    /// EVENTS
    ////////////////////////////////////////////////////////////////

    event L1BlockUpdated(uint256 indexed epoch, uint256 blockNumber, bytes32 blockHash, uint256 timestamp);
    event OracleAdded(address indexed oracle);

    ////////////////////////////////////////////////////////////////
    /// MODIFIERS
    ////////////////////////////////////////////////////////////////

    /// @notice Restricts update calls during the protected update window.
    /// The window is defined as the daily epoch (UTC midnight) plus 1 hour.
    /// If the current block.timestamp is less than (epoch + 1h), only governance may call.
    modifier allowedUpdate() {
        // Compute the current day's epoch (UTC midnight)
        uint256 epochStart = (block.timestamp / 86400) * 86400;
        if (block.timestamp < epochStart + 3600) {
            require(msg.sender == governance, "Only governance allowed during update window");
        }
        _;
    }

    /// @notice Restricts access to La Poste only.
    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    /// @notice Restricts access to the current governance.
    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// CONSTRUCTOR
    ////////////////////////////////////////////////////////////////

    /// @notice Initializes the contract.
    /// @param _l1BlockOracle The source L1 block oracle address.
    /// @param _l1Sender The L1 sender address.
    /// @param _laPoste The La Poste address.
    /// @param _oracles An array of initial oracle contract addresses.
    constructor(address _l1BlockOracle, address _l1Sender, address _laPoste, address[] memory _oracles) {
        if (_l1BlockOracle == address(0) || _l1Sender == address(0) || _laPoste == address(0)) {
            revert ZERO_ADDRESS();
        }

        L1_BLOCK_ORACLE = _l1BlockOracle;
        L1_SENDER = _l1Sender;
        LA_POSTE = _laPoste;
        governance = msg.sender;

        for (uint256 i = 0; i < _oracles.length; i++) {
            if (_oracles[i] == address(0)) revert ZERO_ADDRESS();
            oracles.push(IOracle(_oracles[i]));
            emit OracleAdded(_oracles[i]);
        }
    }

    ////////////////////////////////////////////////////////////////
    /// EXTERNAL / PUBLIC FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /// @notice Allows governance to add a new oracle.
    /// @param _oracle The address of the new oracle.
    function addOracle(address _oracle) external onlyGovernance {
        if (_oracle == address(0)) revert ZERO_ADDRESS();
        oracles.push(IOracle(_oracle));
        emit OracleAdded(_oracle);
    }

    /// @notice Updates the L1 block number in all oracles using the L1_BLOCK_ORACLE as source.
    /// During (epoch + 0h) to (epoch + 1h) only governance can trigger this update.
    /// @return number The L1 block number.
    /// @return hash The L1 block hash.
    /// @return timestamp The L1 block timestamp.
    function updateL1BlockNumber() public allowedUpdate returns (uint256 number, bytes32 hash, uint256 timestamp) {
        if (L1_BLOCK_ORACLE == address(0)) revert L1BlockOracleNotSet();

        number = IL1Block(L1_BLOCK_ORACLE).number();
        hash = IL1Block(L1_BLOCK_ORACLE).hash();
        timestamp = IL1Block(L1_BLOCK_ORACLE).timestamp();

        (number, hash, timestamp) = _updateL1BlockNumber(number, hash, timestamp);
        return (number, hash, timestamp);
    }

    /// @notice Updates the L1 block number in all oracles and optionally dispatches the block hash to specified chains.
    /// @param dispatch Whether to send the block hash to the given chains.
    /// @param chainIds The chain IDs to send the block hash to.
    /// @param additionalGasLimit Additional gas limit for dispatching.
    function updateL1BlockNumberAndDispatch(bool dispatch, uint256[] memory chainIds, uint256 additionalGasLimit)
        public
        payable
        allowedUpdate
    {
        (uint256 number, bytes32 hash, uint256 timestamp) = updateL1BlockNumber();
        if (dispatch && chainIds.length > 0) {
            _dispatchMessage(chainIds, number, hash, timestamp, additionalGasLimit);
        }
    }

    /// @notice Receives the block hash from the L1 sender on L2 and updates the L1 block number in all oracles.
    /// @param chainId The chain ID from which the message originates.
    /// @param sender The address that sent the message.
    /// @param data The ABI-encoded block data.
    function receiveMessage(uint256 chainId, address sender, bytes memory data) external onlyLaPoste {
        if (chainId != 1 && sender != L1_SENDER && sender != address(this)) revert WrongSender();

        (uint256 _l1BlockNumber, bytes32 _l1BlockHash, uint256 _l1Timestamp) =
            abi.decode(data, (uint256, bytes32, uint256));
        _updateL1BlockNumber(_l1BlockNumber, _l1BlockHash, _l1Timestamp);
    }

    /// @notice Allows governance to propose a new governance address.
    /// @param _futureGovernance The new future governance address.
    function transferGovernance(address _futureGovernance) external onlyGovernance {
        if (_futureGovernance == address(0)) revert ZERO_ADDRESS();
        futureGovernance = _futureGovernance;
    }

    /// @notice Accepts the governance role via the future governance address.
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }

    ////////////////////////////////////////////////////////////////
    /// INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////

    /// @dev Internal function that updates the L1 block number in all oracles.
    /// @param _l1BlockNumber The L1 block number.
    /// @param _l1BlockHash The L1 block hash.
    /// @param _l1Timestamp The L1 block timestamp.
    /// @return number The updated L1 block number (from the first oracle).
    /// @return hash The updated L1 block hash.
    /// @return timestamp The updated L1 block timestamp.
    function _updateL1BlockNumber(uint256 _l1BlockNumber, bytes32 _l1BlockHash, uint256 _l1Timestamp)
        internal
        returns (uint256 number, bytes32 hash, uint256 timestamp)
    {
        // Group block numbers per epoch (using 1 week epochs).
        uint256 epoch = (_l1Timestamp / 1 weeks) * 1 weeks;
        for (uint256 i = 0; i < oracles.length; i++) {
            // Retrieve existing block header data for this epoch.
            StateProofVerifier.BlockHeader memory blockData = oracles[i].epochBlockNumber(epoch);
            if (blockData.number == 0) {
                // Insert block header data if not already present.
                oracles[i].insertBlockNumber(
                    epoch,
                    StateProofVerifier.BlockHeader({
                        number: _l1BlockNumber,
                        stateRootHash: bytes32(0),
                        hash: _l1BlockHash,
                        timestamp: _l1Timestamp
                    })
                );
            }
        }
        // Return the block data from the first oracle as representative.
        StateProofVerifier.BlockHeader memory blockData0 = oracles[0].epochBlockNumber(epoch);
        emit L1BlockUpdated(epoch, blockData0.number, blockData0.hash, blockData0.timestamp);
        return (blockData0.number, blockData0.hash, blockData0.timestamp);
    }

    /// @dev Sends the block hash to the specified chains.
    /// @param chainIds The destination chain IDs.
    /// @param number The L1 block number.
    /// @param hash The L1 block hash.
    /// @param timestamp The L1 block timestamp.
    /// @param additionalGasLimit Additional gas limit for the message dispatch.
    function _dispatchMessage(
        uint256[] memory chainIds,
        uint256 number,
        bytes32 hash,
        uint256 timestamp,
        uint256 additionalGasLimit
    ) internal {
        bytes memory data = abi.encode(number, hash, timestamp);
        uint256 numChains = chainIds.length;
        // Divide the provided msg.value equally among chain messages.
        for (uint256 i = 0; i < numChains;) {
            ILaPoste(LA_POSTE).sendMessage{value: msg.value / numChains}(
                ILaPoste.MessageParams({
                    destinationChainId: chainIds[i],
                    to: address(this),
                    tokens: new ILaPoste.Token[](0),
                    payload: data
                }),
                additionalGasLimit,
                msg.sender
            );
            unchecked {
                i++;
            }
        }
    }
}
