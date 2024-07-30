// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "solady/src/utils/Multicallable.sol";
import "solady/src/utils/ReentrancyGuard.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "solady/src/utils/FixedPointMathLib.sol";

/// Project Interfaces & Libraries
import "src/interfaces/IHook.sol";
import "src/interfaces/IVotemarket.sol";

/// @notice Vote market contract.
/// Next iteration of the Votemarket contract. This contract is designed to store the state of each campaign and allow the claim at any point in time.
/// It uses storage proofs to validate and verify the votes and distribute the rewards accordingly.
/// @dev This contract is better suited for L2s. Unadvised to deploy on L1.
/// The contract is MultiCall compatible, to allow for batch calls.
/// @custom:contact contact@stakedao.org
contract Votemarket is ReentrancyGuard, Multicallable {
    using FixedPointMathLib for uint256;

    ////////////////////////////////////////////////////////////////
    /// --- CONSTANT VALUES
    ///////////////////////////////////////////////////////////////

    /// @notice Minimum duration for a campaign.
    uint8 public constant MINIMUM_PERIODS = 2;

    /// @notice Default fee.
    /// @dev 1e18 = 100%. Hence, 2e16 = 2%.
    uint256 private constant _DEFAULT_FEE = 2e16;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Campaigns count.
    uint256 public campaignCount;

    /// @notice Custom fee per manager.
    mapping(address => uint256) public customFeeByManager;

    /// @notice Campaigns by Id.
    mapping(uint256 => Campaign) public campaignById;

    /// @notice Hook by campaign Id.
    mapping(uint256 => address) public hookByCampaignId;

    /// @notice Periods by campaign Id and period Id.
    mapping(uint256 => mapping(uint256 => Period)) public periodByCampaignId;

    /// @notice Campaign Upgrades in queue by Id. To be applied at the next action. (claim, upgrade)
    mapping(uint256 => CampaignUpgrade) public campaignUpgradeById;

    /// @notice Blacklisted addresses per campaign.
    mapping(uint256 => address[]) public blacklistById;

    /// @notice Blacklisted addresses per campaign that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Whitelisted addresses per campaign that are exclusively counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isWhitelisted;

    ////////////////////////////////////////////////////////////////
    /// ---  EVENTS & ERRORS
    ///////////////////////////////////////////////////////////////

    error ZERO_INPUT();
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error CAMPAIGN_ENDED();
    error AUTH_MANAGER_ONLY();
    error INVALID_NUMBER_OF_PERIODS();

    event CampaignCreated(
        uint256 campaignId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount
    );

    event CampaignUpgraded(
        uint256 campaignId, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    /// TODO: Implement remote managers.
    /// Usecase is when the manager is cross-chain message.
    modifier onlyManagerOrRemote(uint256 campaignId) {
        if (msg.sender != campaignById[campaignId].manager) revert AUTH_MANAGER_ONLY();
        _;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CAMPAIGN MANAGEMENT
    ///////////////////////////////////////////////////////////////

    /// @notice Create a new incentive campaign.
    function createCampaign(
        uint256 chainId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata blacklist,
        address hook,
        bool isWhitelist
    ) external nonReentrant {
        if (numberOfPeriods < MINIMUM_PERIODS) revert INVALID_NUMBER_OF_PERIODS();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert ZERO_INPUT();
        if (rewardToken == address(0) || gauge == address(0)) revert ZERO_ADDRESS();

        /// Check if reward token is a contract.
        uint256 size;
        assembly {
            size := extcodesize(rewardToken)
        }
        if (size == 0) revert INVALID_TOKEN();

        /// Transfer reward token to this contract.
        SafeTransferLib.safeTransferFrom(rewardToken, msg.sender, address(this), totalRewardAmount);

        /// Generate campaign Id.
        uint256 campaignId = campaignCount;

        /// Increment campaign count.
        ++campaignCount;

        /// Store campaign.
        campaignById[campaignId] = Campaign({
            chainId: chainId,
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            endTimestamp: currentPeriod() + numberOfPeriods * 1 weeks
        });

        /// Check validity of the hook.
        /// TODO: How to check if the hook is valid?
        bool isValidHook = IHook(hook).validateHook();
        if (isValidHook) {
            /// We do not want to revert the transaction if the hook is invalid.
            /// By default, if the hook is invalid, the campaign will rollover.
            hookByCampaignId[campaignId] = hook;
        }

        /// Store blacklisted or whitelisted addresses.
        /// If blacklisted, the addresses will be subtracted from the total votes.
        /// If whitelisted, only the addresses will be eligible for rewards.
        if (isWhitelist) {
            for (uint256 i = 0; i < blacklist.length; i++) {
                isWhitelisted[campaignId][blacklist[i]] = true;
            }
        } else {
            for (uint256 i = 0; i < blacklist.length; i++) {
                isBlacklisted[campaignId][blacklist[i]] = true;
            }

            /// Store blacklisted addresses.
            blacklistById[campaignId] = blacklist;
        }

        /// Initialize the first period.
        uint256 rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfPeriods);

        /// Store the first period.
        periodByCampaignId[campaignId][0] =
            Period({startTimestamp: currentPeriod() + 1 weeks, rewardPerPeriod: rewardPerPeriod});

        emit CampaignCreated(
            campaignId, gauge, manager, rewardToken, numberOfPeriods, maxRewardPerVote, totalRewardAmount
        );
    }

    /// @notice Manage the campaign duration, total reward amount, and max reward per vote.
    /// @param campaignId Id of the campaign.
    /// @param numberOfPeriods Number of periods to add.
    /// @param totalRewardAmount Total reward amount to add.
    /// @param maxRewardPerVote Max reward per vote to add.
    /// @dev The manager can rug the campaign by manipulating the maxRewardPerVote, or dilute the totalRewardAmount.
    function increaseCampaignDuration(
        uint256 campaignId,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    ) external nonReentrant onlyManagerOrRemote(campaignId) {
        /// Check if the campaign is ended.
        if (getPeriodsLeft(campaignId) == 0) revert CAMPAIGN_ENDED();

        /// Get the campaign.
        Campaign storage campaign = campaignById[campaignId];

        /// Check if there's a campaign upgrade in queue.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId];

        if (campaignUpgrade.totalRewardAmount != 0) {
            SafeTransferLib.safeTransferFrom(
                campaign.rewardToken, msg.sender, address(this), campaignUpgrade.totalRewardAmount
            );
        }

        uint256 updatedMaxRewardPerVote = campaign.maxRewardPerVote;
        if (maxRewardPerVote > 0) {
            updatedMaxRewardPerVote = maxRewardPerVote;
        }

        /// If there's a campaign upgrade in queue, we add the new values to it.
        if (campaignUpgrade.totalRewardAmount != 0) {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaignUpgrade.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaignUpgrade.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: updatedMaxRewardPerVote,
                endTimestamp: campaignUpgrade.endTimestamp + (numberOfPeriods * 1 weeks)
            });
        } else {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaign.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaign.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: updatedMaxRewardPerVote,
                endTimestamp: campaign.endTimestamp + (numberOfPeriods * 1 weeks)
            });
        }

        /// Store the campaign upgrade in queue.
        campaignUpgradeById[campaignId] = campaignUpgrade;

        emit CampaignUpgraded(campaignId, numberOfPeriods, totalRewardAmount, updatedMaxRewardPerVote);
    }

    ////////////////////////////////////////////////////////////////
    /// --- GETTERS
    ///////////////////////////////////////////////////////////////

    function getPeriodsLeft(uint256 campaignId) public view returns (uint256 periodsLeft) {
        Campaign storage campaign = campaignById[campaignId];

        uint256 currentPeriod_ = currentPeriod();
        periodsLeft = campaign.endTimestamp > currentPeriod_ ? (campaign.endTimestamp - currentPeriod_) / 1 weeks : 0;
    }

    function getCampaign(uint256 campaignId) public view returns (Campaign memory) {
        return campaignById[campaignId];
    }

    function getCampaignUpgrade(uint256 campaignId) public view returns (CampaignUpgrade memory) {
        return campaignUpgradeById[campaignId];
    }

    function getBlacklistByCampaignId(uint256 campaignId) public view returns (address[] memory) {
        return blacklistById[campaignId];
    }

    function getPeriodPerCampaignId(uint256 campaignId, uint256 periodId) public view returns (Period memory) {
        return periodByCampaignId[campaignId][periodId];
    }

    function currentPeriod() public view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }
}
