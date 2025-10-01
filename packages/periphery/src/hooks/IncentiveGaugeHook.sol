// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";
import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";
import "src/interfaces/IRemote.sol";

/// @title IncentiveGaugeHook - Hook to redistribute unspent campaign rewards (leftovers) to Merkl
/// @notice This hook collects campaign leftovers on L2 and bridges them to Ethereum mainnet
///         where Merkl redistributes them to incentivize gauges.
/// @dev Intended to be used by Votemarket during `_updateRewardPerVote` when configured.
///      The workflow is:
///      1. Votemarket calls doSomething() to register leftover tokens
///      2. Anyone can call bridge() to send the pending incentive to Merkl on mainnet
/// @custom:contact contact@stakedao.org
contract IncentiveGaugeHook {
    /// -----------------------------------------------------------------------
    /// Governance state
    /// -----------------------------------------------------------------------

    /// @notice Active governance address with full administrative control
    address public governance;

    /// @notice Future governance address for 2-step governance transfer
    /// @dev Used in the transferGovernance/acceptGovernance pattern for safe ownership transfer
    address public futureGovernance;

    /// -----------------------------------------------------------------------
    /// Incentive configuration
    /// -----------------------------------------------------------------------

    /// @notice Address of the Merkl contract on Ethereum mainnet
    /// @dev This is the destination contract that will receive and redistribute the incentives
    address public merkl;

    /// @notice Default duration (in seconds) for newly bridged incentives
    /// @dev This determines how long the incentive will be active on Merkl
    uint256 public duration;

    /// -----------------------------------------------------------------------
    /// Internal storage
    /// -----------------------------------------------------------------------

    /// @notice Structure for incentives pending bridging
    /// @dev Stores all necessary information to bridge a leftover to mainnet
    struct PendingIncentive {
        address votemarket;   // Votemarket contract that generated the leftover
        uint256 _campaignId;  // Campaign ID within the votemarket
        address _rewardToken; // Reward token address on the current L2
        uint256 _leftover;    // Amount of leftover reward tokens to bridge
    }

    /// @notice Queue of pending incentives waiting to be bridged
    /// @dev Mapping from incentive ID to its details. ID starts at 0 and increments.
    mapping(uint256 id => PendingIncentive) public pendingIncentives;

    /// @notice Current number of pending incentives (also serves as next ID)
    /// @dev Incremented each time a new incentive is added via doSomething()
    uint256 public nbPendingIncentives;

    /// @notice Whitelist of authorized votemarkets
    /// @dev Only whitelisted votemarkets can call {doSomething} to register leftovers
    mapping(address votemarket => bool isAuthorized) public votemarkets;

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error AUTH_GOVERNANCE_ONLY();   // Thrown when caller is not governance
    error ZERO_ADDRESS();           // Thrown when a required address is zero
    error UNAUTHORIZED();           // Thrown when an address is not authorized
    error UNAUTHORIZED_VOTEMARKET();// Thrown when caller is not an authorized votemarket
    error WRONG_INCENTIVE();        // Thrown when trying to bridge an invalid/non-existent incentive

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Emitted when leftover is successfully bridged to Merkl
    /// @param votemarket Address of the votemarket that generated the leftover
    /// @param campaignId ID of the campaign within the votemarket
    /// @param gauge Address of the gauge to incentivize on mainnet
    /// @param rewardToken Address of the reward token on L2
    /// @param nativeToken Address of the equivalent token on mainnet
    /// @param leftoverAmount Amount of tokens bridged
    /// @param duration Duration of the incentive on Merkl
    event IncentiveSent(
        address indexed votemarket,
        uint256 indexed campaignId,
        address indexed gauge,
        address rewardToken,
        address nativeToken,
        uint256 leftoverAmount,
        uint256 duration
    );

    /// @notice Emitted when a votemarket is added to the whitelist
    event EnabledVotemarket(address indexed votemarket);

    /// @notice Emitted when a votemarket is removed from the whitelist
    event DisabledVotemarket(address indexed votemarket);

    /// @notice Emitted when the default incentive duration is updated
    event NewDuration(uint256 duration);

    /// @notice Emitted when the Merkl contract address is updated
    event NewMerkl(address merkl);

    /// -----------------------------------------------------------------------
    /// Cross-chain data structures
    /// -----------------------------------------------------------------------

    /// @notice Data sent in the payload to Merkl on mainnet
    /// @dev Encoded and passed through LaPoste bridge to configure the incentive on Merkl
    struct CrossChainIncentive {
        address gauge;    // Gauge to incentivize on mainnet
        address reward;   // Native ERC20 token (mainnet equivalent of the L2 token)
        uint256 duration; // Duration of the incentive in seconds
        uint256 amount;   // Amount of tokens to distribute as incentive
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

    /// @notice Restricts function access to governance only
    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    /// @notice Initializes the contract with governance, duration and Merkl address
    /// @param _governance Initial governance address
    /// @param _duration Default incentive duration in seconds
    /// @param _merkl Merkl contract address on Ethereum mainnet
    constructor(address _governance, uint256 _duration, address _merkl) {
        governance = _governance;
        duration = _duration;
        merkl = _merkl;
    }

    /// -----------------------------------------------------------------------
    /// Core functions
    /// -----------------------------------------------------------------------

    /// @notice Called by Votemarket when campaign leftovers are detected
    /// @dev Adds a new pending incentive entry that can later be bridged.
    ///      This function is called automatically by whitelisted Votemarket contracts
    ///      when they detect unspent rewards after a campaign ends.
    /// @param _campaignId ID of the campaign generating the leftover
    /// @param _chainId Current chain ID (unused in current implementation, reserved for future use)
    /// @param _rewardToken Address of the reward token on this L2
    /// @param _epoch Campaign epoch (unused in current implementation, reserved for future use)
    /// @param _leftover Amount of leftover tokens to bridge
    /// @dev The last parameter (bytes calldata) is unused but kept for interface compatibility
    function doSomething(
        uint256 _campaignId,
        uint256 _chainId,
        address _rewardToken,
        uint256 _epoch,
        uint256 _leftover,
        bytes calldata
    ) external payable {
        // Only whitelisted votemarkets can register leftovers
        if (!votemarkets[msg.sender]) revert UNAUTHORIZED_VOTEMARKET();

        // Register pending incentive with all necessary information
        PendingIncentive memory pendingIncentive = PendingIncentive({
            votemarket: msg.sender,
            _campaignId: _campaignId,
            _rewardToken: _rewardToken,
            _leftover: _leftover
        });

        // Store the pending incentive and increment counter
        pendingIncentives[nbPendingIncentives] = pendingIncentive;
        nbPendingIncentives++;
    }

    /// @notice Bridges a specific pending incentive to Merkl on mainnet
    /// @dev Maps L2 reward token to mainnet equivalent, prepares payload,
    ///      and calls LaPoste bridge to transfer funds and data.
    ///      This function can be called by anyone and requires ETH to pay for bridge fees.
    /// @param pendingIncentiveId ID of the pending incentive to bridge
    /// @param additionalGasLimit Additional gas to add to the bridge transaction for execution on mainnet
    function bridge(uint256 pendingIncentiveId, uint256 additionalGasLimit) external payable {
        // Retrieve the pending incentive
        PendingIncentive memory pendingIncentive = pendingIncentives[pendingIncentiveId];
        if (pendingIncentive.votemarket == address(0)) revert WRONG_INCENTIVE();

        IVotemarket votemarket = IVotemarket(pendingIncentive.votemarket);

        // Retrieve gauge address from the campaign
        uint256 _campaignId = pendingIncentive._campaignId;
        address gauge = votemarket.getCampaign(_campaignId).gauge;

        // Resolve bridge infrastructure contracts (LaPoste and TokenFactory)
        (address laPoste, address tokenFactory) = _get_addresses(votemarket);

        // Map L2 token to its native mainnet equivalent
        address _rewardToken = pendingIncentive._rewardToken;
        address nativeToken = ITokenFactory(tokenFactory).nativeTokens(_rewardToken);

        // Get leftover amount to bridge
        uint256 _leftover = pendingIncentive._leftover;

        // Prepare bridge message with tokens and payload
        ILaPoste.MessageParams memory messageParams = _get_laposte_message(gauge, nativeToken, _rewardToken, _leftover);

        // Execute bridge call (requires ETH for bridge fees)
        ILaPoste(laPoste).sendMessage{value: msg.value}(messageParams, additionalGasLimit, address(this));

        // Emit event for tracking
        emit IncentiveSent(address(votemarket), _campaignId, gauge, _rewardToken, nativeToken, _leftover, duration);

        // Clean up the pending incentive
        delete pendingIncentives[pendingIncentiveId];
    }

    /// @notice Internal helper to retrieve bridge-related contract addresses
    /// @dev Gets LaPoste and TokenFactory addresses from the votemarket's remote contract
    /// @param votemarket The votemarket contract to query
    /// @return laPoste Address of the LaPoste bridge contract
    /// @return tokenFactory Address of the TokenFactory contract for token mapping
    function _get_addresses(IVotemarket votemarket) internal returns (address, address) {
        address remote = votemarket.remote();
        address laPoste = IRemote(remote).LA_POSTE();
        address tokenFactory = IRemote(remote).TOKEN_FACTORY();

        return (laPoste, tokenFactory);
    }

    /// @notice Internal helper to construct the LaPoste bridge message
    /// @dev Prepares the message parameters including tokens to bridge and encoded payload
    /// @param gauge Address of the gauge to incentivize on mainnet
    /// @param nativeToken Address of the native token on mainnet
    /// @param _rewardToken Address of the reward token on L2
    /// @param _leftover Amount of tokens to bridge
    /// @return messageParams Struct containing all bridge message parameters
    function _get_laposte_message(address gauge, address nativeToken, address _rewardToken, uint256 _leftover) internal returns (ILaPoste.MessageParams memory) {

        // Prepare token array for bridging (only one token per incentive)
        ILaPoste.Token[] memory laPosteTokens = new ILaPoste.Token[](1);
        laPosteTokens[0] = ILaPoste.Token({tokenAddress: _rewardToken, amount: _leftover});

        // Encode cross-chain incentive data for Merkl to parse
        CrossChainIncentive memory crossChainIncentive = CrossChainIncentive({
            gauge: gauge,
            reward: nativeToken,
            duration: duration,
            amount: _leftover
        });

        // Prepare complete bridge message
        return ILaPoste.MessageParams({
            destinationChainId: 1, // Ethereum mainnet
            to: merkl,             // Merkl contract receives the incentive
            tokens: laPosteTokens, // Tokens to bridge
            payload: abi.encode(crossChainIncentive) // Encoded incentive data
        });
    }

    /// -----------------------------------------------------------------------
    /// Governance functions
    /// -----------------------------------------------------------------------

    /// @notice Adds a votemarket to the whitelist
    /// @dev Only whitelisted votemarkets can call doSomething() to register leftovers
    /// @param _votemarket Address of the votemarket to whitelist
    function enableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = true;
        emit EnabledVotemarket(_votemarket);
    }

    /// @notice Removes a votemarket from the whitelist
    /// @param _votemarket Address of the votemarket to remove
    function disableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = false;
        emit DisabledVotemarket(_votemarket);
    }

    /// @notice Rescue any ERC20 token mistakenly sent to this contract
    /// @dev Emergency function to recover tokens sent by mistake
    /// @param _token Address of the token to rescue
    /// @param _amount Amount of tokens to rescue
    /// @param _recipient Address to receive the rescued tokens
    function rescueERC20(address _token, uint256 _amount, address _recipient) external onlyGovernance {
        if (_recipient == address(0)) revert ZERO_ADDRESS();
        SafeTransferLib.safeTransfer(_token, _recipient, _amount);
    }

    /// @notice Step 1/2 - Propose new governance
    /// @dev Initiates a 2-step governance transfer for safety
    /// @param _futureGovernance Address of the proposed new governance
    function transferGovernance(address _futureGovernance) external onlyGovernance {
        if (_futureGovernance == address(0)) revert ZERO_ADDRESS();
        futureGovernance = _futureGovernance;
    }

    /// @notice Step 2/2 - Accept governance
    /// @dev Must be called by the futureGovernance address to complete the transfer
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }

    /// @notice Update default incentive duration
    /// @dev Changes the duration applied to all future bridged incentives
    /// @param _duration New duration in seconds
    function setDuration(uint256 _duration) external onlyGovernance {
        duration = _duration;
        emit NewDuration(duration);
    }

    /// @notice Update Merkl contract address (mainnet)
    /// @dev Changes the destination address for future bridged incentives
    /// @param _merkl New Merkl contract address on Ethereum mainnet
    function setMerkl(address _merkl) external onlyGovernance {
        merkl = _merkl;
        emit NewMerkl(merkl);
    }
}