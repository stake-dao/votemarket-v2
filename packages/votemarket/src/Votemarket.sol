// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "@solady/src/utils/Multicallable.sol";
import "@solady/src/utils/ReentrancyGuard.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/FixedPointMathLib.sol";

/// Project Interfaces & Libraries
import "src/interfaces/IHook.sol";
import "src/interfaces/IVotemarket.sol";
import "src/interfaces/IOracleLens.sol";

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

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Governance address.
    address public governance;

    /// @notice Oracle address.
    address public oracle;

    /// @notice Address of the remote cross-chain message handler.
    address public remote;

    /// @notice Fee receiver.
    address public feeCollector;

    /// @notice Fee.
    uint256 public fee;

    /// @notice Campaigns count.
    uint256 public campaignCount;

    /// @notice Claim deadline in seconds.
    uint256 public claimDeadline;

    /// @notice Close deadline in seconds.
    uint256 public closeDeadline;

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

    /// @notice Total claimed per campaign Id.
    mapping(uint256 => uint256) public totalClaimedByCampaignId;

    /// @notice Total claimed per period Id.
    mapping(uint256 => mapping(uint256 => uint256)) public totalClaimedByPeriodId;

    /// @notice Total claimed per user per campaign Id and period Id.
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalClaimedByUser;

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
    error INVALID_INPUT();

    error CAMPAIGN_ENDED();
    error CAMPAIGN_NOT_ENDED();

    error AUTH_MANAGER_ONLY();
    error AUTH_GOVERNANCE_ONLY();

    event CampaignCreated(
        uint256 campaignId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount
    );

    event CampaignUpgradeQueued(
        uint256 campaignId, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    event CampaignUpgraded(
        uint256 campaignId, uint8 numberOfPeriods, uint256 totalRewardAmount, uint256 maxRewardPerVote
    );

    event CampaignClosed(uint256 campaignId);

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    /// TODO: Implement remote managers.
    /// Usecase is when the manager is cross-chain message.
    modifier onlyManagerOrRemote(uint256 campaignId) {
        _isManagerOrRemote(campaignId);
        _;
    }

    /// @notice Check if the manager or remote is calling the function.
    function _isManagerOrRemote(uint256 campaignId) internal view {
        if (msg.sender != campaignById[campaignId].manager && msg.sender != remote) revert AUTH_MANAGER_ONLY();
    }

    constructor() {
        /// TODO: Put it as a parameter for create3 deployment.
        governance = msg.sender;
        feeCollector = msg.sender;

        /// Default fee is 4%.
        fee = 4e16;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CLAIM LOGIC
    ///////////////////////////////////////////////////////////////

    function _claim(address account, address gauge, uint256 epoch) internal {}

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
        if (numberOfPeriods < MINIMUM_PERIODS) revert INVALID_INPUT();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert ZERO_INPUT();
        if (rewardToken == address(0) || gauge == address(0)) revert ZERO_ADDRESS();

        /// Check if reward token is a contract.
        uint256 size;
        assembly {
            size := extcodesize(rewardToken)
        }
        if (size == 0) revert INVALID_TOKEN();

        /// Transfer reward token to this contract.
        SafeTransferLib.safeTransferFrom({
            token: rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

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
    function manageCampaign(
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

        if (totalRewardAmount != 0) {
            SafeTransferLib.safeTransferFrom({
                token: campaign.rewardToken,
                from: msg.sender,
                to: address(this),
                amount: totalRewardAmount
            });
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

        emit CampaignUpgradeQueued(campaignId, numberOfPeriods, totalRewardAmount, updatedMaxRewardPerVote);
    }

    /// @notice Increase the total reward amount, public function.
    /// @param campaignId Id of the campaign.
    /// @param totalRewardAmount Total reward amount to add.
    /// @dev For convenience, this function can be called by anyone.
    function increaseTotalRewardAmount(uint256 campaignId, uint256 totalRewardAmount) external nonReentrant {
        if (totalRewardAmount == 0) revert ZERO_INPUT();

        /// Get the campaign.
        Campaign memory campaign = campaignById[campaignId];

        /// Check if there's a campaign upgrade in queue.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId];

        SafeTransferLib.safeTransferFrom({
            token: campaignById[campaignId].rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

        /// If there's a campaign upgrade in queue, we add the new values to it.
        if (campaignUpgrade.totalRewardAmount != 0) {
            campaignUpgrade.totalRewardAmount += totalRewardAmount;
        } else {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaign.numberOfPeriods,
                totalRewardAmount: campaign.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: campaign.maxRewardPerVote,
                endTimestamp: campaign.endTimestamp
            });
        }

        campaignUpgradeById[campaignId] = campaignUpgrade;

        emit CampaignUpgradeQueued(
            campaignId,
            campaignUpgrade.numberOfPeriods,
            campaignUpgrade.totalRewardAmount,
            campaignUpgrade.maxRewardPerVote
        );
    }

    /// @notice Close the campaign.
    /// @dev There's multiple conditions to check before closing the campaign.
    /// 1. If the campaign didn't started yet, it can be closed immediately.
    /// 2. The campaign must be ended. If there's an upgrade in queue, it'll be applied before closing the campaign.
    /// 3. The campaign can't be closed before the claim deadline.
    /// 4. After the claim deadline, the campaign can be closed by the manager or remote, but within a certain timeframe (close deadline)
    /// else remaining funds will be sent to the fee receiver.
    function closeCampaign(uint256 campaignId) external nonReentrant {
        /// Get the campaign.
        Campaign storage campaign = campaignById[campaignId];

        /// Check if there is an upgrade in queue and update the campaign.
        _checkForUpgrade({campaignId: campaignId});

        /// Claim deadline is the end timestamp + claim deadline.
        uint256 claimDeadline_ = campaign.endTimestamp + claimDeadline;

        /// Close deadline is the end timestamp + close deadline.
        uint256 closeDeadline_ = claimDeadline_ + closeDeadline;

        /// Check if the campaign started.
        uint256 startTimestamp = periodByCampaignId[campaignId][0].startTimestamp;

        if (block.timestamp >= startTimestamp && block.timestamp < claimDeadline_) {
            revert CAMPAIGN_NOT_ENDED();
        } else if (
            block.timestamp < startTimestamp || (block.timestamp >= claimDeadline_ && block.timestamp < closeDeadline_)
        ) {
            _isManagerOrRemote({campaignId: campaignId});
            _closeCampaign({
                campaignId: campaignId,
                totalRewardAmount: campaign.totalRewardAmount,
                rewardToken: campaign.rewardToken,
                receiver: campaign.manager
            });
        } else if (block.timestamp >= closeDeadline_) {
            _closeCampaign({
                campaignId: campaignId,
                totalRewardAmount: campaign.totalRewardAmount,
                rewardToken: campaign.rewardToken,
                receiver: feeCollector
            });
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- INTERNAL LOGIC IMPLEMENTATION
    ///////////////////////////////////////////////////////////////

    /// @notice Close the campaign.
    /// @param campaignId Id of the campaign.
    /// @param totalRewardAmount Total reward amount to claim.
    /// @param rewardToken Reward token address.
    /// @param receiver Receiver address.
    function _closeCampaign(uint256 campaignId, uint256 totalRewardAmount, address rewardToken, address receiver)
        internal
    {
        uint256 leftOver = totalRewardAmount - totalClaimedByCampaignId[campaignId];

        // Transfer the left over to the receiver.
        SafeTransferLib.safeTransfer({token: rewardToken, to: receiver, amount: leftOver});
        delete campaignById[campaignId].manager;

        emit CampaignClosed(campaignId);
    }

    /// @notice Check if there is an upgrade in queue.
    /// @param campaignId Id of the campaign.
    function _checkForUpgrade(uint256 campaignId) internal {
        /// Get the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId];

        // Check if there is an upgrade in queue.
        if (campaignUpgrade.totalRewardAmount != 0) {
            /// Get the second period.
            Period storage secondPeriod = periodByCampaignId[campaignId][1];

            // Save new values.
            campaignById[campaignId].endTimestamp = campaignUpgrade.endTimestamp;
            campaignById[campaignId].numberOfPeriods = campaignUpgrade.numberOfPeriods;
            campaignById[campaignId].maxRewardPerVote = campaignUpgrade.maxRewardPerVote;
            campaignById[campaignId].totalRewardAmount = campaignUpgrade.totalRewardAmount;

            /// If the campaign didn't sart yet, we need to update the first period reward per period as it is done in the create campaign function.
            if (secondPeriod.startTimestamp == 0) {
                periodByCampaignId[campaignId][0].rewardPerPeriod =
                    campaignUpgrade.totalRewardAmount.mulDiv(1, campaignUpgrade.numberOfPeriods);
            }

            emit CampaignUpgraded(
                campaignId,
                campaignUpgrade.numberOfPeriods,
                campaignUpgrade.totalRewardAmount,
                campaignUpgrade.maxRewardPerVote
            );

            // Reset the next values.
            delete campaignUpgradeById[campaignId];
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- GETTERS
    ///////////////////////////////////////////////////////////////

    /// @notice Returns the number of weeks before the campaign ends.
    /// @param campaignId Id of the campaign.
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

    function getBlacklistByCampaign(uint256 campaignId) public view returns (address[] memory) {
        return blacklistById[campaignId];
    }

    function getPeriodPerCampaign(uint256 campaignId, uint256 periodId) public view returns (Period memory) {
        return periodByCampaignId[campaignId][periodId];
    }

    function currentPeriod() public view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    function setFee(uint256 _fee) external onlyGovernance {
        /// Fee cannot be higher than 10%.
        if (_fee > 10e16) revert INVALID_INPUT();

        fee = _fee;
    }

    function setRemote(address _remote) external onlyGovernance {
        if (_remote == address(0)) revert ZERO_ADDRESS();

        remote = _remote;
    }

    function setFeeCollector(address _feeCollector) external onlyGovernance {
        if (_feeCollector == address(0)) revert ZERO_ADDRESS();

        feeCollector = _feeCollector;
    }

    function setCloseDeadline(uint256 _closeDeadline) external onlyGovernance {
        closeDeadline = _closeDeadline;
    }

    function setClaimDeadline(uint256 _claimDeadline) external onlyGovernance {
        claimDeadline = _claimDeadline;
    }
}
