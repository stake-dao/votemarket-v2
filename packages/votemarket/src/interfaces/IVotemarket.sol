// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

////////////////////////////////////////////////////////////////
/// --- DATA STRUCTURE DEFINITIONS
///////////////////////////////////////////////////////////////

struct Campaign {
    /// @notice Chain Id of the destination chain where the gauge is deployed.
    uint256 chainId;
    /// @notice Destination gauge address.
    address gauge;
    /// @notice Address to manage the campaign.
    address manager;
    /// @notice Main reward token.
    address rewardToken;
    /// @notice Duration of the campaign in weeks.
    uint8 numberOfPeriods;
    /// @notice Maximum reward per vote to distribute, to avoid overspending.
    uint256 maxRewardPerVote;
    /// @notice Total reward amount to distribute.
    uint256 totalRewardAmount;
    /// @notice Start timestamp of the campaign.
    uint256 startTimestamp;
    /// @notice End timestamp of the campaign.
    uint256 endTimestamp;
}

/// @notice Claim data struct to avoid stack too deep errors.
struct ClaimData {
    /// @notice Campaign ID.
    uint256 campaignId;
    /// @notice Account address.
    address account;
    /// @notice Receiver address.
    address receiver;
    /// @notice Epoch to claim.
    uint256 epoch;
    /// @notice Amount to claim.
    uint256 amountToClaim;
    /// @notice Fee amount.
    uint256 feeAmount;
}

struct Period {
    /// @notice Start timestamp of the period.
    uint256 startTimestamp;
    /// @notice Amount of reward reserved for the period.
    uint256 rewardPerPeriod;
    /// @notice  Leftover amount.
    uint256 leftover;
    /// @notice Flag to indicate if the period is updated.
    bool updated;
}

struct CampaignUpgrade {
    /// @notice Number of periods after increase.
    uint8 numberOfPeriods;
    /// @notice Total reward amount after increase.
    uint256 totalRewardAmount;
    /// @notice New max reward per vote after increase.
    uint256 maxRewardPerVote;
    /// @notice New end timestamp after increase.
    uint256 endTimestamp;
}

interface IVotemarket {}
