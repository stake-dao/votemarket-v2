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
/// @custom:contact contact@stakedao.org
contract IncentiveGaugeHook {
    /// -----------------------------------------------------------------------
    /// Governance state
    /// -----------------------------------------------------------------------

    /// @notice Active governance address
    address public governance;

    /// @notice Future governance address for 2-step governance transfer
    address public futureGovernance;

    /// -----------------------------------------------------------------------
    /// Incentive configuration
    /// -----------------------------------------------------------------------

    /// @notice Address of the Merkl contract on Ethereum mainnet
    address public merkl;

    /// @notice Default duration (in seconds) for newly bridged incentives
    uint256 public duration;

    /// -----------------------------------------------------------------------
    /// Internal storage
    /// -----------------------------------------------------------------------

    /// @notice Structure for incentives pending bridging
    struct PendingIncentive {
        address votemarket;   // Votemarket contract that generated the leftover
        uint256 _campaignId;  // Campaign ID within the votemarket
        address _rewardToken; // Reward token address on the current L2
        uint256 _leftover;    // Amount of leftover reward tokens
    }

    /// @notice Queue of pending incentives waiting to be bridged
    mapping(uint256 id => PendingIncentive) pendingIncentives;

    /// @notice Current number of pending incentives (also serves as next ID)
    uint256 public nbPendingIncentives;

    /// @notice Whitelist of authorized votemarkets
    /// @dev Only whitelisted votemarkets can call {doSomething}
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

    /// @notice Emitted when leftover is bridged to Merkl
    event IncentiveSent(
        address indexed votemarket,
        uint256 indexed campaignId,
        address indexed gauge,
        address rewardToken,
        address nativeToken,
        uint256 leftoverAmount,
        uint256 duration
    );

    event EnabledVotemarket(address indexed votemarket);
    event DisabledVotemarket(address indexed votemarket);
    event NewDuration(uint256 duration);
    event NewMerkl(address merkl);

    /// -----------------------------------------------------------------------
    /// Cross-chain data structures
    /// -----------------------------------------------------------------------

    /// @notice Data sent in the payload to Merkl on mainnet
    /// @dev Encoded and passed through LaPoste bridge
    struct CrossChainIncentive {
        address gauge;    // Gauge to incentivize on mainnet
        address reward;   // Native ERC20 token (mainnet equivalent)
        uint256 duration; // Duration of the incentive
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

    /// @param _governance Initial governance address
    /// @param _duration Default incentive duration
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
    /// @dev Adds a new pending incentive entry that can later be bridged
    /// @param _campaignId ID of the campaign generating the leftover
    /// @param _chainId Current chain ID (unused in current implementation)
    /// @param _rewardToken Address of the reward token on this L2
    /// @param _epoch Campaign epoch (unused in current implementation)
    /// @param _leftover Amount of leftover tokens to bridge
    function doSomething(
        uint256 _campaignId,
        uint256 _chainId,
        address _rewardToken,
        uint256 _epoch,
        uint256 _leftover,
        bytes calldata
    ) external payable {
        if (!votemarkets[msg.sender]) revert UNAUTHORIZED_VOTEMARKET();

        // Register pending incentive
        PendingIncentive memory pendingIncentive = PendingIncentive({
            votemarket: msg.sender,
            _campaignId: _campaignId,
            _rewardToken: _rewardToken,
            _leftover: _leftover
        });

        pendingIncentives[nbPendingIncentives] = pendingIncentive;
        nbPendingIncentives++;
    }

    /// @notice Bridges a specific pending incentive to Merkl on mainnet
    /// @dev Maps L2 reward token to mainnet equivalent, prepares payload,
    ///      and calls LaPoste bridge to transfer funds and data.
    /// @param pendingIncentiveId ID of the pending incentive to bridge
    function bridge(uint256 pendingIncentiveId) external payable {
        PendingIncentive memory pendingIncentive = pendingIncentives[pendingIncentiveId];
        if (pendingIncentive.votemarket == address(0)) revert WRONG_INCENTIVE();

        IVotemarket votemarket = IVotemarket(pendingIncentive.votemarket);

        // Retrieve gauge from campaign
        uint256 _campaignId = pendingIncentive._campaignId;
        address gauge = votemarket.getCampaign(_campaignId).gauge;

        // Resolve bridge infrastructure contracts
        address remote = votemarket.remote();
        address laPoste = IRemote(remote).LA_POSTE();
        address tokenFactory = IRemote(remote).TOKEN_FACTORY();

        // Map L2 token to native mainnet token
        address _rewardToken = pendingIncentive._rewardToken;
        address nativeToken = ITokenFactory(tokenFactory).nativeTokens(_rewardToken);

        // Prepare tokens for bridging
        uint256 _leftover = pendingIncentive._leftover;
        ILaPoste.Token[] memory laPosteTokens = new ILaPoste.Token[](1);
        laPosteTokens[0] = ILaPoste.Token({tokenAddress: _rewardToken, amount: _leftover});

        // Encode cross-chain incentive for Merkl
        CrossChainIncentive memory crossChainIncentive = CrossChainIncentive({
            gauge: gauge,
            reward: nativeToken,
            duration: duration
        });

        // Prepare bridge message
        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: 1, // Ethereum mainnet
            to: merkl,             // Merkl contract receives incentive
            tokens: laPosteTokens,
            payload: abi.encode(crossChainIncentive)
        });

        // Execute bridge call
        ILaPoste(laPoste).sendMessage{value: msg.value}(messageParams, 0, address(this));

        emit IncentiveSent(address(votemarket), _campaignId, gauge, _rewardToken, nativeToken, _leftover, duration);

        delete pendingIncentives[pendingIncentiveId];
    }

    /// -----------------------------------------------------------------------
    /// Governance functions
    /// -----------------------------------------------------------------------

    function enableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = true;
        emit EnabledVotemarket(_votemarket);
    }

    function disableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = false;
        emit DisabledVotemarket(_votemarket);
    }

    /// @notice Rescue any ERC20 token mistakenly sent to this contract
    function rescueERC20(address _token, uint256 _amount, address _recipient) external onlyGovernance {
        if (_recipient == address(0)) revert ZERO_ADDRESS();
        SafeTransferLib.safeTransfer(_token, _recipient, _amount);
    }

    /// @notice Step 1/2 - Propose new governance
    function transferGovernance(address _futureGovernance) external onlyGovernance {
        if (_futureGovernance == address(0)) revert ZERO_ADDRESS();
        futureGovernance = _futureGovernance;
    }

    /// @notice Step 2/2 - Accept governance
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }

    /// @notice Update default incentive duration
    function setDuration(uint256 _duration) external onlyGovernance {
        duration = _duration;
        emit NewDuration(duration);
    }

    /// @notice Update Merkl contract address (mainnet)
    function setMerkl(address _merkl) external onlyGovernance {
        merkl = _merkl;
        emit NewMerkl(merkl);
    }
}