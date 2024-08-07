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
    /// @notice End timestamp of the campaign.
    uint256 endTimestamp;
}

struct Period {
    /// @notice Start timestamp of the period.
    uint256 startTimestamp;
    /// @notice Amount of reward reserved for the period.
    uint256 rewardPerPeriod;
    /// @notice  Leftover amount.
    uint256 leftover;
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
