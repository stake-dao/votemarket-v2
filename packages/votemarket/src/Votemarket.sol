// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// TODO: REMOVE
import "@forge-std/src/Test.sol";

/// External Libraries
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
/// @custom:contact contact@stakedao.org
contract Votemarket is ReentrancyGuard {
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

    /// @notice Periods by campaign Id and Epoch.
    mapping(uint256 => mapping(uint256 => Period)) public periodByCampaignId;

    /// @notice Reward Per Vote by campaign Id and Epoch.
    mapping(uint256 => mapping(uint256 => uint256)) public rewardPerVoteByCampaignId;

    /// @notice Campaign Upgrades in queue by Id. To be applied at the next action. (claim, upgrade)
    mapping(uint256 => mapping(uint256 => CampaignUpgrade)) public campaignUpgradeById;

    /// @notice Total claimed per campaign Id.
    mapping(uint256 => uint256) public totalClaimedByCampaignId;

    /// @notice Total claimed per period Id.
    mapping(uint256 => mapping(uint256 => uint256)) public totalClaimedByPeriodId;

    /// @notice Total claimed per user per campaign Id and period Id.
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalClaimedByUser;

    /// @notice Blacklisted addresses per campaign.
    mapping(uint256 => address[]) public blacklistById;

    /// @notice Mapping of campaign ids that are whitelist only.
    mapping(uint256 => bool) public whitelistOnly;

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
    error PREVIOUS_STATE_MISSING();

    error CAMPAIGN_ENDED();
    error CAMPAIGN_NOT_ENDED();

    error AUTH_BLACKLISTED();
    error AUTH_MANAGER_ONLY();
    error AUTH_WHITELIST_ONLY();
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

    modifier checkWhitelist(uint256 campaignId, address account) {
        if (whitelistOnly[campaignId]) {
            if (!isWhitelisted[campaignId][account]) revert AUTH_WHITELIST_ONLY();
        }
        _;
    }

    modifier checkBlacklist(uint256 campaignId, address account) {
        if (isBlacklisted[campaignId][account]) revert AUTH_BLACKLISTED();
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

        /// 3 months.
        closeDeadline = 12 weeks;
        claimDeadline = 12 weeks;

        /// Default fee is 4%.
        fee = 4e16;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CLAIM LOGIC
    ///////////////////////////////////////////////////////////////

    function _claim(uint256 campaignId, address account, uint256 epoch)
        internal
        checkWhitelist(campaignId, account)
        checkBlacklist(campaignId, account)
        returns (uint256 claimed)
    {
        /// Update the epoch.
        epoch = _updateEpoch(campaignId, epoch);

        return claimed;
    }

    function updateEpoch(uint256 campaignId, uint256 epoch) external returns (uint256 epoch_) {
        epoch_ = _updateEpoch(campaignId, epoch);
    }

    function _updateEpoch(uint256 campaignId, uint256 epoch) internal returns (uint256 epoch_) {
        if (_isEpochAlreadyUpdated(campaignId, epoch)) return epoch;

        _validatePreviousState(campaignId, epoch);
        _checkForUpgrade(campaignId, epoch);

        uint256 remainingPeriods = getRemainingPeriods(campaignId, epoch);
        uint256 totalRewardForRemainingPeriods = _calculateTotalReward(campaignId, epoch, remainingPeriods);

        /// Update Period.
        Period storage period = _getPeriod(campaignId, epoch);
        period.startTimestamp = epoch;
        period.rewardPerPeriod = totalRewardForRemainingPeriods.mulDiv(1, remainingPeriods);

        _updateRewardPerVote(campaignId, epoch, period);

        return epoch;
    }

    function _isEpochAlreadyUpdated(uint256 campaignId, uint256 epoch) internal view returns (bool) {
        return rewardPerVoteByCampaignId[campaignId][epoch] != 0;
    }

    function _validatePreviousState(uint256 campaignId, uint256 epoch) internal view {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - 1 weeks];

        if (previousPeriod.startTimestamp == 0 && !_isEpochAlreadyUpdated(campaignId, epoch)) {
            revert PREVIOUS_STATE_MISSING();
        }
    }

    function _getPeriod(uint256 campaignId, uint256 epoch) internal view returns (Period storage) {
        return periodByCampaignId[campaignId][epoch];
    }

    function _calculateTotalReward(uint256 campaignId, uint256 epoch, uint256 remainingPeriods)
        internal
        view
        returns (uint256)
    {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - 1 weeks];
        Period storage currentPeriod = periodByCampaignId[campaignId][epoch];
        return previousPeriod.leftover + currentPeriod.rewardPerPeriod * remainingPeriods;
    }

    function _updateRewardPerVote(uint256 campaignId, uint256 epoch, Period storage period) internal {
        /// To mark the epoch as updated. If non of the conditions are met.
        uint256 rewardPerVote = 1;
        if (whitelistOnly[campaignId]) {
            rewardPerVote = campaignById[campaignId].maxRewardPerVote;
        } else {
            uint256 totalVotes = _getAdjustedVote(campaignId, epoch);

            if (totalVotes != 0) {
                rewardPerVote = period.rewardPerPeriod.mulDiv(1, totalVotes);

                if (rewardPerVote > campaignById[campaignId].maxRewardPerVote) {
                    rewardPerVote = campaignById[campaignId].maxRewardPerVote;

                    uint256 leftOver = period.rewardPerPeriod - rewardPerVote.mulDiv(totalVotes, 1);

                    if (hookByCampaignId[campaignId] != address(0)) {
                        SafeTransferLib.safeTransfer({
                            token: campaignById[campaignId].rewardToken,
                            to: hookByCampaignId[campaignId],
                            amount: leftOver
                        });
                    } else {
                        period.leftover = leftOver;
                    }
                }
            }
        }

        /// Save the reward per vote.
        rewardPerVoteByCampaignId[campaignId][epoch] = rewardPerVote;
    }

    function _getAdjustedVote(uint256 campaignId, uint256 epoch) internal view returns (uint256) {
        address[] memory blacklist = getBlacklistByCampaign(campaignId);

        uint256 totalVotes = IOracleLens(oracle).getTotalVotes(campaignById[campaignId].gauge, epoch);

        uint256 blacklistedVotes;
        for (uint256 i = 0; i < blacklist.length; i++) {
            blacklistedVotes += IOracleLens(oracle).getAccountVotes(blacklist[i], campaignById[campaignId].gauge, epoch);
        }

        return totalVotes - blacklistedVotes;
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
    ) external nonReentrant returns (uint256 campaignId) {
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
        campaignId = campaignCount;

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
            endTimestamp: currentEpoch() + numberOfPeriods * 1 weeks
        });

        /// Store the hook.
        /// No need to check if the hook is valid.
        hookByCampaignId[campaignId] = hook;

        /// Store blacklisted or whitelisted addresses.
        /// If blacklisted, the addresses will be subtracted from the total votes.
        /// If whitelisted, only the addresses will be eligible for rewards.
        if (isWhitelist) {
            for (uint256 i = 0; i < blacklist.length; i++) {
                isWhitelisted[campaignId][blacklist[i]] = true;
            }

            /// Flag the campaign as whitelist only.
            whitelistOnly[campaignId] = true;
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
            Period({startTimestamp: currentEpoch() + 1 weeks, rewardPerPeriod: rewardPerPeriod, leftover: 0});

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
        if (getRemainingPeriods(campaignId, currentEpoch()) == 0) revert CAMPAIGN_ENDED();

        uint256 epoch = currentEpoch() + 1 weeks;

        /// Get the campaign.
        Campaign storage campaign = campaignById[campaignId];

        /// Check if there's a campaign upgrade in queue.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[epoch][campaignId];

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
        campaignUpgradeById[epoch][campaignId] = campaignUpgrade;

        emit CampaignUpgradeQueued(campaignId, numberOfPeriods, totalRewardAmount, updatedMaxRewardPerVote);
    }

    /// @notice Increase the total reward amount, public function.
    /// @param campaignId Id of the campaign.
    /// @param totalRewardAmount Total reward amount to add.
    /// @dev For convenience, this function can be called by anyone.
    function increaseTotalRewardAmount(uint256 campaignId, uint256 totalRewardAmount) external nonReentrant {
        if (totalRewardAmount == 0) revert ZERO_INPUT();

        uint256 epoch = currentEpoch() + 1 weeks;

        /// Get the campaign.
        Campaign memory campaign = campaignById[campaignId];

        /// Check if there's a campaign upgrade in queue.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[epoch][campaignId];

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

        campaignUpgradeById[epoch][campaignId] = campaignUpgrade;

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

        /// Claim deadline is the end timestamp + claim deadline.
        uint256 claimDeadline_ = campaign.endTimestamp + claimDeadline;

        /// Close deadline is the end timestamp + close deadline.
        uint256 closeDeadline_ = claimDeadline_ + closeDeadline;

        /// Check if the campaign started.
        uint256 startTimestamp = periodByCampaignId[campaignId][0].startTimestamp;

        /// Can't close the campaign if the campaign is not ended.
        if (block.timestamp >= startTimestamp && block.timestamp < claimDeadline_) {
            revert CAMPAIGN_NOT_ENDED();
        }

        /// Validate the previous state if the campaign is started.
        if (block.timestamp >= startTimestamp) {
            _validatePreviousState(campaignId, campaign.endTimestamp - 1 weeks);
        }

        if (block.timestamp < startTimestamp || (block.timestamp >= claimDeadline_ && block.timestamp < closeDeadline_))
        {
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
    function _checkForUpgrade(uint256 campaignId, uint256 epoch) internal {
        /// Get the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[epoch][campaignId];

        // Check if there is an upgrade in queue.
        if (campaignUpgrade.totalRewardAmount != 0) {
            /// Add to the leftover amount the newly added reward amount so it can be split accordingly to the remaining periods.
            periodByCampaignId[campaignId][epoch - 1 weeks].leftover =
                campaignUpgrade.totalRewardAmount - campaignById[campaignId].totalRewardAmount;

            // Save new values.
            campaignById[campaignId].endTimestamp = campaignUpgrade.endTimestamp;
            campaignById[campaignId].numberOfPeriods = campaignUpgrade.numberOfPeriods;
            campaignById[campaignId].maxRewardPerVote = campaignUpgrade.maxRewardPerVote;
            campaignById[campaignId].totalRewardAmount = campaignUpgrade.totalRewardAmount;

            emit CampaignUpgraded(
                campaignId,
                campaignUpgrade.numberOfPeriods,
                campaignUpgrade.totalRewardAmount,
                campaignUpgrade.maxRewardPerVote
            );
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- GETTERS
    ///////////////////////////////////////////////////////////////

    function isEpochUpdated(uint256 campaignId, uint256 epoch) public view returns (bool) {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - 1 weeks];

        uint256 remainingPeriods = getRemainingPeriods(campaignId, epoch);
        uint256 periodId = remainingPeriods > 0 ? remainingPeriods : 0;

        /// If first epoch, no previous period. If reward per vote is missing, it's not updated.
        return periodId != campaignById[campaignId].numberOfPeriods && previousPeriod.rewardPerPeriod != 0;
    }

    /// @notice Returns the number of weeks before the campaign ends.
    /// @param campaignId Id of the campaign.
    function getRemainingPeriods(uint256 campaignId, uint256 epoch) public view returns (uint256 periodsLeft) {
        Campaign storage campaign = campaignById[campaignId];
        periodsLeft = campaign.endTimestamp > epoch ? (campaign.endTimestamp - epoch) / 1 weeks : 0;
    }

    function getCampaign(uint256 campaignId) public view returns (Campaign memory) {
        return campaignById[campaignId];
    }

    function getCampaignUpgrade(uint256 campaignId, uint256 epoch) public view returns (CampaignUpgrade memory) {
        return campaignUpgradeById[epoch][campaignId];
    }

    function getBlacklistByCampaign(uint256 campaignId) public view returns (address[] memory) {
        return blacklistById[campaignId];
    }

    function getPeriodPerCampaign(uint256 campaignId, uint256 periodId) public view returns (Period memory) {
        return periodByCampaignId[campaignId][periodId];
    }

    function currentEpoch() public view returns (uint256) {
        return block.timestamp / 1 weeks * 1 weeks;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    function setOracle(address _oracle) external onlyGovernance {
        if (_oracle == address(0)) revert ZERO_ADDRESS();

        oracle = _oracle;
    }

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
