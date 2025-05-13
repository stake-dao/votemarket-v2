// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@votemarket/src/interfaces/IVotemarket.sol";
import "@solady/src/utils/SafeTransferLib.sol";

/// @notice Votemarket hook for receiving leftovers
/// @custom:contact contact@stakedao.org
contract LeftoverDistributor {
    /// @notice Governance address.
    address public governance;

    /// @notice Future governance address.
    address public futureGovernance;

    /// @notice Votemarket whitelist
    mapping(address votemarket => bool isAuthorized) public votemarkets;

    /// @notice Leftover recipient by campaign id by votemarket
    mapping(address votemarket => mapping(uint256 campaignId => address recipient)) public leftoverRecipients;

    /// @notice Thrown when a non-governance address attempts a governance-only action.
    error AUTH_GOVERNANCE_ONLY();

    /// @notice Error thrown when an address shouldn't be zero
    error ZERO_ADDRESS();

    /// @notice Error thrown when the address isn't authorized
    error UNAUTHORIZED();

    /// @notice Error thrown when a votemarket isn't whitelisted
    error UNAUTHORIZED_VOTEMARKET();

    /// @notice Emitted when the leftover is sent
    event LeftOverSent(
        address indexed votemarket,
        uint256 indexed campaignId,
        uint256 chainId,
        address rewardToken,
        uint256 indexed epoch,
        uint256 leftoverAmount,
        address recipient
    );

    /// @notice Emitted when a leftoverRecipients is set
    event LeftOverRecipientSet(address indexed votemarket, uint256 indexed campaignId, address indexed recipient);

    /// @notice Emitted when a votemarket is enabled
    event EnabledVotemarket(address indexed votemarket);
    /// @notice Emitted when a votemarket is disabled
    event DisabledVotemarket(address indexed votemarket);

    /// @notice Ensures that only the governance address can call the function.
    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    /// @notice Initializes the governance.
    /// @param _governance The address that will become the initial governance.
    constructor(address _governance) {
        governance = _governance;
    }

    /// @notice Function called by votemarket during an _updateRewardPerVote when hook address is set
    /// @param _campaignId Campaign id on the votemarket calling
    /// @param _rewardToken Reward token address
    /// @param _leftover Leftover amount
    function doSomething(uint256 _campaignId, uint256 _chainId, address _rewardToken, uint256 _epoch, uint256 _leftover, bytes calldata)
        external
    {
        if (!votemarkets[msg.sender]) revert UNAUTHORIZED_VOTEMARKET();
        IVotemarket votemarket = IVotemarket(msg.sender);

        // 1. Define the recipient, either the custom one set, or the manager by default
        address recipient = leftoverRecipients[msg.sender][_campaignId];

        if (recipient == address(0)) recipient = votemarket.getCampaign(_campaignId).manager;
        if (recipient == address(0)) revert ZERO_ADDRESS();

        // 2. Transfer the claimed amount to the recipient.
        SafeTransferLib.safeTransfer(_rewardToken, recipient, _leftover);

        emit LeftOverSent(msg.sender, _campaignId, _chainId, _rewardToken, _epoch, _leftover, recipient);
    }

    /// @notice Set the leftover recipient for a campaign on a votemarket
    /// Can only be called by the campaign manager or the already set recipient
    /// @param _votemarket Votemarket address
    /// @param _campaignId Campaign id on the votemarket
    /// @param _recipient New recipient of leftovers
    function setLeftOverRecipient(address _votemarket, uint256 _campaignId, address _recipient) external {
        if (!votemarkets[_votemarket]) revert UNAUTHORIZED_VOTEMARKET();

        IVotemarket votemarket = IVotemarket(_votemarket);

        if (
            votemarket.getCampaign(_campaignId).manager != msg.sender
                && leftoverRecipients[_votemarket][_campaignId] != msg.sender
        ) revert UNAUTHORIZED();

        leftoverRecipients[_votemarket][_campaignId] = _recipient;

        emit LeftOverRecipientSet(_votemarket, _campaignId, _recipient);
    }

    /// @notice Overrides the leftover recipient for a campaign on a votemarket
    /// Can only be called by the governance
    /// @param _votemarket Votemarket address
    /// @param _campaignId Campaign id on the votemarket
    /// @param _recipient New recipient of leftovers
    function overrideLeftOverRecipient(address _votemarket, uint256 _campaignId, address _recipient) external onlyGovernance {
        if (!votemarkets[_votemarket]) revert UNAUTHORIZED_VOTEMARKET();

        leftoverRecipients[_votemarket][_campaignId] = _recipient;

        emit LeftOverRecipientSet(_votemarket, _campaignId, _recipient);
    }

    /// @notice A function to enable votemarkets on this contract
    /// @param _votemarket Votemarket address to toggle
    function enableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = true;
        emit EnabledVotemarket(_votemarket);
    }

    /// @notice A function to disable votemarkets on this contract
    /// @param _votemarket Votemarket address to toggle
    function disableVotemarket(address _votemarket) external onlyGovernance {
        votemarkets[_votemarket] = false;
        emit DisabledVotemarket(_votemarket);
    }

    /// @notice A function that rescue any ERC20 token
    /// @dev Can be called only by the owner
    /// @param _token token address
    /// @param _amount amount to rescue
    /// @param _recipient address to send token rescued
    function rescueERC20(address _token, uint256 _amount, address _recipient) external onlyGovernance {
        if (_recipient == address(0)) revert ZERO_ADDRESS();
        SafeTransferLib.safeTransfer(_token, _recipient, _amount);
    }

    /// @notice Sets the future governance address
    /// @param _futureGovernance The new future governance address
    function transferGovernance(address _futureGovernance) external onlyGovernance {
        if (_futureGovernance == address(0)) revert ZERO_ADDRESS();
        futureGovernance = _futureGovernance;
    }

    /// @notice Accepts the governance role via the future governance address
    function acceptGovernance() external {
        if (msg.sender != futureGovernance) revert AUTH_GOVERNANCE_ONLY();
        governance = futureGovernance;
        futureGovernance = address(0);
    }
}
