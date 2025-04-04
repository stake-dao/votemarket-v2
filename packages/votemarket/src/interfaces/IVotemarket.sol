// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/EnumerableSetLib.sol";

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
    /// @notice Total reward amount distributed.
    uint256 totalDistributed;
    /// @notice Start timestamp of the campaign.
    uint256 startTimestamp;
    /// @notice End timestamp of the campaign.
    uint256 endTimestamp;
    /// Hook address.
    address hook;
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
    /// @notice Amount of reward reserved for the period.
    uint256 rewardPerPeriod;
    /// @notice Reward Per Vote.
    uint256 rewardPerVote;
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

interface IVotemarket {
    function createCampaign(
        uint256 chainId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] memory addresses,
        address hook,
        bool whitelist
    ) external returns (uint256 campaignId);

    function manageCampaign(
        uint256 campaignId,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    ) external;

    function getCampaign(uint256 campaignId) external view returns (Campaign memory);

    function claim(uint256 campaignId, address account, uint256 epoch, bytes calldata hookData)
        external
        returns (uint256 claimed);

    function updateEpoch(uint256 campaignId, uint256 epoch, bytes calldata hookData) external returns (uint256);

    function updateManager(uint256 campaignId, address newManager) external;

    function closeCampaign(uint256 campaignId) external;

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    function setIsProtected(address _account, bool _isProtected) external;

    function setRemote(address _remote) external;

    function setFee(uint256 _fee) external;

    function setCustomFee(address _account, uint256 _fee) external;

    function setRecipient(address _account, address _recipient) external;

    function setFeeCollector(address _feeCollector) external;

    function transferGovernance(address _futureGovernance) external;

    function acceptGovernance() external;
}
