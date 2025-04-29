// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "@votemarket/src/interfaces/IVotemarket.sol";
import "@solady/src/utils/SafeTransferLib.sol";

/// @notice Votemarket hook for receiving leftovers
/// @custom:contact contact@stakedao.org
contract NoRolloverHook {
    /// @notice Left over recipient by campaign id by platform
    mapping(address => mapping(uint256 => address)) public leftOverRecipient;

    /// @notice Error thrown when an address shouldn't be zero
    error ZERO_ADDRESS();

    /// @notice Error thrown when the address isn't authorized
    error UNAUTHORIZED();

    /// @notice Function called by votemarket during an _updateRewardPerVote when hook address is set
    function doSomething(uint256 campaignId, uint256, address rewardToken, uint256, uint256 leftOver, bytes calldata)
        external
    {
        IVotemarket votemarket = IVotemarket(msg.sender);

        // 1. Define the recipient, either the custom one set, or the manager by default
        address recipient = leftOverRecipient[msg.sender][campaignId];

        if (recipient == address(0)) recipient = votemarket.getCampaign(campaignId).manager;
        if (recipient == address(0)) revert ZERO_ADDRESS();

        // 2. Transfer the claimed amount to the recipient.
        SafeTransferLib.safeTransfer(rewardToken, recipient, leftOver);
    }

    /// @notice Set the left over recipient for a campaign on a votemarket platform
    /// Can only be called by the campaign amanager or the already set recipient
    function setLeftOverRecipient(address platform, uint256 campaignId, address recipient) external {
        IVotemarket votemarket = IVotemarket(platform);

        if (
            votemarket.getCampaign(campaignId).manager != msg.sender
                || leftOverRecipient[platform][campaignId] != msg.sender
        ) revert UNAUTHORIZED();

        leftOverRecipient[platform][campaignId] = recipient;
    }
}
