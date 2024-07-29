// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "solady/src/utils/ReentrancyGuard.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "solady/src/utils/FixedPointMathLib.sol";

/// Project Interfaces & Libraries
import "src/interfaces/IHook.sol";
import "src/interfaces/ILaPlace.sol";

/// @notice Vote market contract.
/// @custom:contact contact@stakedao.org
contract Votemarket is ReentrancyGuard {
    using FixedPointMathLib for uint256;

    struct Campaign {
        uint256 chainId;
        address gauge;
        address manager;
        address rewardToken;
        uint8 numberOfPeriods;
        uint256 maxRewardPerVote;
        uint256 totalRewardAmount;
        uint256 endTimestamp;
    }

    struct Period {
        uint256 startTimestamp;
        uint256 rewardPerPeriod;
    }

    /// @notice Campaigns count.
    uint256 campaignCount;

    /// @notice Minimum duration a Bounty.
    uint8 public constant MINIMUM_PERIODS = 2;

    /// @notice Default fee.
    /// @dev 1e18 = 100%.
    uint256 private constant _DEFAULT_FEE = 2e16; // 2%

    /// @notice Custom fee per manager.
    mapping(address => uint256) public customFeePerManager;

    /// @notice Campaigns by ID.
    mapping(uint256 => Campaign) public campaignById;

    /// @notice Periods by campaign ID and period ID.
    mapping(uint256 => mapping(uint256 => Period)) public periodByCampaignId;

    /// @notice Blacklisted addresses per campaign.
    mapping(uint256 => address[]) public blacklistById;

    /// @notice Blacklisted addresses per campaign that aren't counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isBlacklisted;

    /// @notice Whitelisted addresses per campaign that are exlusively counted for rewards arithmetics.
    mapping(uint256 => mapping(address => bool)) public isWhitelisted;

    error ZERO_INPUT();
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error INVALID_NUMBER_OF_PERIODS();

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

        /// Check validity of the hook.
        bool isValidHook = IHook(hook).validateHook();
        if (isValidHook) {
            /// TODO: Store the hook for the campaign.
            /// We do not want to revert the transaction if the hook is invalid.
            /// By default, if the hook is invalid, the campaign will rollover.
        }

        /// Generate campaign ID.
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

        /// Store blacklisted or whitelisted addresses.
        /// If blacklisted, the addresses will be substracted from the total votes.
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
        uint256 rewardPerPeriod = totalRewardAmount.mulWad(numberOfPeriods);

        /// Store the first period.
        periodByCampaignId[campaignId][0] =
            Period({startTimestamp: currentPeriod() + 1 weeks, rewardPerPeriod: rewardPerPeriod});
    }

    function currentPeriod() public view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }
}
