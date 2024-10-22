// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "src/interfaces/IL1Block.sol";
import "src/interfaces/ILaPoste.sol";
import "@votemarket/src/interfaces/IOracle.sol";

/// @notice A module for updating the L1 block number in the oracle, and block hash.
contract L1BlockOracleUpdater {
    /// @notice The L1 sender address.
    address public immutable L1_SENDER;

    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The L1 block oracle address.
    address public immutable L1_BLOCK_ORACLE;

    /// @notice The oracle address.
    address public immutable ORACLE;

    /// @notice The error emitted when the caller is not the La Poste address.
    error NotLaPoste();

    /// @notice The error emitted when the sender is not the L1 sender address.
    error WrongSender();

    /// @notice The error emitted when the L1 block oracle is not set.
    /// @dev For some chains, we'll allow only updates from the L1 sender address.
    error L1BlockOracleNotSet();

    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    constructor(address _l1BlockOracle, address _l1Sender, address _laPoste, address _oracle) {
        ORACLE = _oracle;
        LA_POSTE = _laPoste;
        L1_SENDER = _l1Sender;
        L1_BLOCK_ORACLE = _l1BlockOracle;
    }

    function updateL1BlockNumber() public returns (uint256 number, bytes32 hash, uint256 timestamp) {
        if (L1_BLOCK_ORACLE == address(0)) revert L1BlockOracleNotSet();

        number = IL1Block(L1_BLOCK_ORACLE).number();
        hash = IL1Block(L1_BLOCK_ORACLE).hash();
        timestamp = IL1Block(L1_BLOCK_ORACLE).timestamp();

        return _updateL1BlockNumber(number, hash, timestamp);
    }

    function updateL1BlockNumberAndDispatch(bool dispatch, uint256[] memory chainIds) public payable {
        (uint256 number, bytes32 hash, uint256 timestamp) = updateL1BlockNumber();
        if (dispatch && chainIds.length > 0) _dispatchMessage(chainIds, number, hash, timestamp);
    }

    function receiveMessage(uint256 chainId, address sender, bytes memory data) external onlyLaPoste {
        if (chainId != 1 && sender != L1_SENDER && sender != address(this)) revert WrongSender();

        (uint256 _l1BlockNumber, bytes32 _l1BlockHash, uint256 _l1Timestamp) =
            abi.decode(data, (uint256, bytes32, uint256));
        _updateL1BlockNumber(_l1BlockNumber, _l1BlockHash, _l1Timestamp);
    }

    function _updateL1BlockNumber(uint256 _l1BlockNumber, bytes32 _l1BlockHash, uint256 _l1Timestamp)
        internal
        returns (uint256 number, bytes32 hash, uint256 timestamp)
    {
        uint256 epoch = _l1Timestamp / 1 weeks * 1 weeks;
        StateProofVerifier.BlockHeader memory blockData = IOracle(ORACLE).epochBlockNumber(epoch);

        if (blockData.number == 0) {
            IOracle(ORACLE).insertBlockNumber(
                epoch,
                StateProofVerifier.BlockHeader({
                    number: _l1BlockNumber,
                    stateRootHash: bytes32(0),
                    hash: _l1BlockHash,
                    timestamp: _l1Timestamp
                })
            );

            blockData = IOracle(ORACLE).epochBlockNumber(epoch);
        }

        return (blockData.number, blockData.hash, blockData.timestamp);
    }

    function _dispatchMessage(uint256[] memory chainIds, uint256 number, bytes32 hash, uint256 timestamp) internal {
        bytes memory data = abi.encode(number, hash, timestamp);

        for (uint256 i = 0; i < chainIds.length;) {
            ILaPoste(LA_POSTE).sendMessage{value: msg.value / chainIds.length}(
                ILaPoste.MessageParams({
                    destinationChainId: chainIds[i],
                    to: address(this),
                    token: ILaPoste.Token({tokenAddress: address(0), amount: 0}),
                    payload: data
                }),
                200_000,
                msg.sender
            );
            unchecked {
                i++;
            }
        }
    }
}
