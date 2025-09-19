// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";
import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";
import "src/interfaces/IRemote.sol";

/// @title IncentiveGaugeHook - Hook to redistribute leftovers to Merkl
/// @notice This contract automatically bridges unspent amounts (leftovers) from L2 
///         to Ethereum mainnet to incentivize gauges via Merkl
/// @dev Hook called automatically by Votemarket during _updateRewardPerVote
/// @custom:contact contact@stakedao.org
contract IncentiveGaugeHook {
    /// @notice Governance address of the contract
    address public governance;

    /// @notice Future governance address (for 2-step governance transfer)
    address public futureGovernance;

    /// @notice Address of the Merkl contract on Ethereum mainnet that will receive incentives
    address public merkl;

    /// @notice Default duration for incentives in seconds
    uint256 public duration;

    /// @notice Whitelist of votemarkets authorized to use this hook
    /// @dev Only whitelisted votemarkets can call doSomething()
    mapping(address votemarket => bool isAuthorized) public votemarkets;

    /// @notice Thrown when a governance-only action is attempted by non-governance
    error AUTH_GOVERNANCE_ONLY();

    /// @notice Thrown when an address should not be zero
    error ZERO_ADDRESS();

    /// @notice Thrown when an address is not authorized
    error UNAUTHORIZED();

    /// @notice Thrown when a votemarket is not whitelisted
    error UNAUTHORIZED_VOTEMARKET();

    /// @notice Emitted when leftover is bridged to Merkl to incentivize a gauge
    /// @param votemarket Address of the votemarket that generated the leftover
    /// @param campaignId ID of the concerned campaign
    /// @param gauge Address of the gauge that will be incentivized on mainnet
    /// @param rewardToken Original reward token on L2
    /// @param nativeToken Corresponding native token on mainnet
    /// @param leftoverAmount Amount of leftover bridged
    /// @param duration Duration of the incentive
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

    /// @notice Emitted when the default duration is updated
    event NewDuration(uint256 duration);

    /// @notice Emitted when the Merkl address is updated
    event NewMerkl(address merkl);

    /// @notice Structure to transmit cross-chain incentive data
    /// @dev Minimal structure to reduce gas costs during bridging
    struct CrossChainIncentive {
        address gauge;    // Address of the gauge that will receive rewards on mainnet
        address reward;   // Address of the native ERC20 token used as reward
        uint256 duration; // Duration of the incentive in seconds
    }

    /// @notice Modifier to ensure only governance can call the function
    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    /// @notice Initializes the contract with base parameters
    /// @param _governance Address that will become the initial governance
    /// @param _duration Default duration for incentives in seconds
    /// @param _merkl Address of the Merkl contract on mainnet
    constructor(address _governance, uint256 _duration, address _merkl) {
        governance = _governance;
        duration = _duration;
        merkl = _merkl;
    }

    /// @notice Main hook function called by Votemarket when processing campaign leftovers
    /// @dev Called automatically during _updateRewardPerVote when hook address is set
    /// @param _campaignId ID of the campaign generating the leftover
    /// @param _chainId Chain ID where the campaign is running (unused in current implementation)
    /// @param _rewardToken Address of the reward token on the current L2
    /// @param _epoch Epoch number (unused in current implementation)
    /// @param _leftover Amount of leftover tokens to bridge and use for incentives
    /// @param Additional data (unused in current implementation)
    function doSomething(
        uint256 _campaignId,
        uint256 _chainId,
        address _rewardToken,
        uint256 _epoch,
        uint256 _leftover,
        bytes calldata
    ) external payable {
        if (!votemarkets[msg.sender]) revert UNAUTHORIZED_VOTEMARKET();

        bridge(_campaignId, _rewardToken, _leftover);
    }

    /// @notice Internal function to bridge leftover tokens to mainnet for Merkl incentives
    /// @dev Retrieves campaign info, maps tokens, and sends cross-chain message via LaPoste
    /// @param _campaignId ID of the campaign to get gauge information
    /// @param _rewardToken L2 reward token address to bridge
    /// @param _leftover Amount of tokens to bridge
    function bridge(uint256 _campaignId, address _rewardToken, uint256 _leftover) internal {
        IVotemarket votemarket = IVotemarket(msg.sender);
        
        // Get the gauge address from the campaign
        address gauge = votemarket.getCampaign(_campaignId).gauge;

        // Get bridge infrastructure contracts
        address remote = votemarket.remote();
        address laPoste = IRemote(remote).LA_POSTE();
        address tokenFactory = IRemote(remote).TOKEN_FACTORY();
        
        // Map L2 token to its mainnet equivalent
        address nativeToken = ITokenFactory(tokenFactory).nativeTokens(_rewardToken);

        // Prepare tokens for bridging
        ILaPoste.Token[] memory laPosteTokens = new ILaPoste.Token[](1);
        laPosteTokens[0] = ILaPoste.Token({tokenAddress: _rewardToken, amount: _leftover});

        // Prepare incentive data for Merkl
        CrossChainIncentive memory crossChainIncentive = CrossChainIncentive({
            gauge: gauge,
            reward: nativeToken,
            duration: duration
        });

        // Prepare bridge message to mainnet
        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: 1, // Ethereum mainnet
            to: merkl,             // Merkl contract will receive the incentive
            tokens: laPosteTokens,
            payload: abi.encode(crossChainIncentive)
        });

        // Send the cross-chain message with tokens
        ILaPoste(laPoste).sendMessage{value: msg.value}(messageParams, 0, address(this));

        emit IncentiveSent(address(votemarket), _campaignId, gauge, _rewardToken, nativeToken, _leftover, duration);
    }

    /// @notice Adds a votemarket to the authorized whitelist
    /// @dev Only governance can authorize new votemarkets to use this hook
    /// @param _votemarket Address of the votemarket to enable
    function enableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = true;
        emit EnabledVotemarket(_votemarket);
    }

    /// @notice Removes a votemarket from the authorized whitelist
    /// @dev Only governance can revoke votemarket authorization
    /// @param _votemarket Address of the votemarket to disable
    function disableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = false;
        emit DisabledVotemarket(_votemarket);
    }

    /// @notice Emergency function to rescue any ERC20 token from the contract
    /// @dev Only callable by governance, useful for recovering stuck tokens
    /// @param _token Address of the token to rescue
    /// @param _amount Amount of tokens to rescue
    /// @param _recipient Address that will receive the rescued tokens
    function rescueERC20(address _token, uint256 _amount, address _recipient) external onlyGovernance {
        if (_recipient == address(0)) revert ZERO_ADDRESS();
        SafeTransferLib.safeTransfer(_token, _recipient, _amount);
    }

    /// @notice Initiates governance transfer to a new address (step 1 of 2)
    /// @dev New governance must call acceptGovernance() to complete the transfer
    /// @param _futureGovernance Address of the proposed new governance
    function transferGovernance(address _futureGovernance) external onlyGovernance {
        if (_futureGovernance == address(0)) revert ZERO_ADDRESS();
        futureGovernance = _futureGovernance;
    }

    /// @notice Completes governance transfer (step 2 of 2)
    /// @dev Can only be called by the address set in transferGovernance()
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }

    /// @notice Updates the default duration for incentives
    /// @dev Duration is used for all future incentives bridged to Merkl
    /// @param _duration New duration in seconds
    function setDuration(uint256 _duration) external onlyGovernance {
        duration = _duration;
        emit NewDuration(duration);
    }

    /// @notice Updates the Merkl contract address on mainnet
    /// @dev Changes where incentives are sent on Ethereum mainnet
    /// @param _merkl New Merkl contract address
    function setMerkl(address _merkl) external onlyGovernance {
        merkl = _merkl;
        emit NewMerkl(merkl);
    }
}