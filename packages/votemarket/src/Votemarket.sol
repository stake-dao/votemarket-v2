// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// External Libraries
import "@solady/src/utils/ReentrancyGuard.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@solady/src/utils/EnumerableSetLib.sol";
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
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    ////////////////////////////////////////////////////////////////
    /// --- CONSTANT VALUES
    ///////////////////////////////////////////////////////////////

    /// @notice Minimum duration for a campaign.
    uint8 public immutable MINIMUM_PERIODS;

    /// @notice Epoch length in seconds.
    uint256 public immutable EPOCH_LENGTH;

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

    /// @notice Protected addresses.
    /// @dev Smart Contracts addresses that cannot set recipients by themselves, or didn't manage to replicate the address on L2.
    /// Example: Yearn yCRV Locker, Convex VoterProxy, StakeDAO Locker.
    mapping(address => bool) public isProtected;

    /// @notice Recipients.
    mapping(address => address) public recipients;

    /// @notice Custom fee per manager.
    mapping(address => uint256) public customFeeByManager;

    /// @notice Campaigns by Id.
    mapping(uint256 => Campaign) public campaignById;

    /// @notice Hook by campaign Id.
    mapping(uint256 => address) public hookByCampaignId;

    /// @notice Periods by campaign Id and Epoch.
    mapping(uint256 => mapping(uint256 => Period)) public periodByCampaignId;

    /// @notice Campaign Upgrades in queue by Id. To be applied at the next action. (claim, upgrade)
    mapping(uint256 => mapping(uint256 => CampaignUpgrade)) public campaignUpgradeById;

    /// @notice Total claimed per campaign Id.
    mapping(uint256 => uint256) public totalClaimedByCampaignId;

    /// @notice Total claimed per user per campaign Id and period Id.
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalClaimedByAccount;

    /// @notice Mapping of campaign ids that are whitelist only.
    mapping(uint256 => bool) public whitelistOnly;

    /// @notice Whitelisted/Blacklisted addresses per campaign.
    mapping(uint256 => EnumerableSetLib.AddressSet) public addressesSet;

    ////////////////////////////////////////////////////////////////
    /// ---  EVENTS & ERRORS
    ///////////////////////////////////////////////////////////////

    error ZERO_INPUT();
    error ZERO_ADDRESS();
    error INVALID_TOKEN();
    error INVALID_INPUT();
    error PROTECTED_ACCOUNT();
    error PREVIOUS_STATE_MISSING();
    error CLAIM_AMOUNT_EXCEEDS_REWARD_AMOUNT();

    error CAMPAIGN_ENDED();
    error CAMPAIGN_NOT_ENDED();
    error EPOCH_NOT_VALID();

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

    event CampaignUpgradeQueued(uint256 campaignId, uint256 epoch);

    event CampaignUpgraded(uint256 campaignId, uint256 epoch);

    event CampaignClosed(uint256 campaignId);

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    modifier checkWhitelistOrBlacklist(uint256 campaignId, address account) {
        EnumerableSetLib.AddressSet storage addressesSet_ = addressesSet[campaignId];
        bool contains = addressesSet_.contains(account);
        if (whitelistOnly[campaignId] && !contains) {
            revert AUTH_WHITELIST_ONLY();
        } else if (!whitelistOnly[campaignId] && contains) {
            revert AUTH_BLACKLISTED();
        }
        _;
    }

    modifier validEpoch(uint256 campaignId, uint256 epoch) {
        if (
            epoch > block.timestamp || epoch < campaignById[campaignId].startTimestamp
                || epoch >= campaignById[campaignId].endTimestamp
        ) revert EPOCH_NOT_VALID();
        _;
    }

    modifier onlyManagerOrRemote(uint256 campaignId) {
        _isManagerOrRemote(campaignId);
        _;
    }

    /// @notice Check if the manager or remote is calling the function.
    function _isManagerOrRemote(uint256 campaignId) internal view {
        if (msg.sender != campaignById[campaignId].manager && msg.sender != remote) revert AUTH_MANAGER_ONLY();
    }

    constructor(
        address _governance,
        address _feeCollector,
        uint256 _closeDeadline,
        uint256 _claimDeadline,
        uint256 _epochLength,
        uint8 _minimumPeriods
    ) {
        governance = _governance;
        feeCollector = _feeCollector;

        /// 6 months.
        closeDeadline = _closeDeadline;
        claimDeadline = _claimDeadline;

        /// Default fee is 4%.
        fee = 4e16;

        EPOCH_LENGTH = _epochLength;
        MINIMUM_PERIODS = _minimumPeriods;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CLAIM LOGIC
    ///////////////////////////////////////////////////////////////

    function claim(uint256 campaignId, address account, uint256 epoch, bytes calldata hookData)
        external
        nonReentrant
        returns (uint256 claimed)
    {
        /// 1. Check if the account is protected.
        if (isProtected[account] && recipients[account] == address(0)) revert PROTECTED_ACCOUNT();

        /// 2. Set the receiver.
        address receiver = recipients[account] == address(0) ? account : recipients[account];

        return _claim(
            ClaimData({
                campaignId: campaignId,
                account: account,
                receiver: receiver,
                epoch: epoch,
                amountToClaim: 0,
                feeAmount: 0
            }),
            hookData
        );
    }

    /// @notice Allows a user to claim rewards for a campaign
    /// @param campaignId The ID of the campaign
    /// @param receiver The address to receive the rewards
    /// @param epoch The epoch for which to claim rewards
    /// @param hookData Additional data for hooks
    /// @return claimed The amount of rewards claimed
    function claim(uint256 campaignId, uint256 epoch, bytes calldata hookData, address receiver)
        external
        nonReentrant
        returns (uint256 claimed)
    {
        return _claim(
            ClaimData({
                campaignId: campaignId,
                account: msg.sender,
                receiver: receiver,
                epoch: epoch,
                amountToClaim: 0,
                feeAmount: 0
            }),
            hookData
        );
    }

    /// @notice Internal function to process a claim
    /// @param data The claim data
    /// @param hookData Additional data for hooks
    /// @return claimed The amount of rewards claimed
    function _claim(ClaimData memory data, bytes calldata hookData)
        internal
        checkWhitelistOrBlacklist(data.campaignId, data.account)
        validEpoch(data.campaignId, data.epoch)
        returns (uint256 claimed)
    {
        /// Update the epoch if needed.
        data.epoch = _updateEpoch(data.campaignId, data.epoch, hookData);

        /// Check if the account respect the conditions to claim.
        if (!_canClaim(data)) return 0;

        /// Get the amount to claim and the fee amount.
        (data.amountToClaim, data.feeAmount) = _calculateClaimAndFee(data);

        /// Check if the total claimed amount plus the claimed amount exceeds the total reward amount.
        if (
            totalClaimedByCampaignId[data.campaignId] + data.amountToClaim + data.feeAmount
                > campaignById[data.campaignId].totalRewardAmount
        ) revert CLAIM_AMOUNT_EXCEEDS_REWARD_AMOUNT();

        /// Update the total claimed amount for the account in this campaign and epoch.
        _updateClaimState(data);

        /// Transfer the tokens to the receiver.
        _transferTokens(data);

        return data.amountToClaim;
    }

    /// @notice Checks if a claim is valid
    /// @param data The claim data
    /// @return bool True if the claim is valid, false otherwise
    function _canClaim(ClaimData memory data) internal view returns (bool) {
        // 1. Retrieve the campaign from storage
        Campaign storage campaign = campaignById[data.campaignId];

        // 2. Check if the account can claim using the oracle
        bool canClaimFromOracle = IOracleLens(oracle).canClaim(data.account, campaign.gauge, data.epoch);

        // 3. Check if the claim deadline has not passed
        bool withinClaimDeadline = campaign.endTimestamp + claimDeadline > block.timestamp;

        // 4. Check if the account has not claimed before or if there's a new reward available
        bool notClaimedOrNoReward = totalClaimedByAccount[data.campaignId][data.epoch][data.account] == 0
            || periodByCampaignId[data.campaignId][data.epoch].rewardPerVote == 0;

        // 5. Return true if all conditions are met
        return canClaimFromOracle && withinClaimDeadline && notClaimedOrNoReward;
    }

    /// @notice Calculates the claim amount and fee
    /// @param data The claim data
    /// @return amountToClaim The amount of rewards to claim
    /// @return feeAmount The fee amount
    function _calculateClaimAndFee(ClaimData memory data)
        internal
        view
        returns (uint256 amountToClaim, uint256 feeAmount)
    {
        // 1. Retrieve the campaign from storage
        Campaign storage campaign = campaignById[data.campaignId];

        // 2. Get the account's votes from the oracle
        uint256 accountVote = IOracleLens(oracle).getAccountVotes(data.account, campaign.gauge, data.epoch);

        // 3. Calculate the amount to claim based on the account's votes and the reward per vote
        amountToClaim = accountVote.mulDiv(periodByCampaignId[data.campaignId][data.epoch].rewardPerVote, 1e18);

        // 4. Determine the fee percentage (custom fee for the manager or default fee)
        uint256 feeBps = customFeeByManager[campaign.manager] > 0 ? customFeeByManager[campaign.manager] : fee;

        // 5. Calculate the fee amount
        feeAmount = amountToClaim.mulDiv(feeBps, 1e18);

        // 6. Subtract the fee from the amount to claim
        amountToClaim -= feeAmount;
    }

    /// @notice Updates the claim state
    /// @param data The claim data
    function _updateClaimState(ClaimData memory data) internal {
        // 1. Update the total claimed amount for the account in this campaign and epoch
        totalClaimedByAccount[data.campaignId][data.epoch][data.account] = data.amountToClaim + data.feeAmount;

        // 3. Update the total claimed amount for the campaign
        totalClaimedByCampaignId[data.campaignId] += data.amountToClaim + data.feeAmount;
    }

    /// @notice Transfers tokens for a claim
    /// @param data The claim data
    function _transferTokens(ClaimData memory data) internal {
        // 1. Get the reward token for the campaign
        address rewardToken = campaignById[data.campaignId].rewardToken;

        // 2. Transfer the claimed amount to the receiver
        SafeTransferLib.safeTransfer(rewardToken, data.receiver, data.amountToClaim);

        // 3. Transfer the fee to the fee collector
        SafeTransferLib.safeTransfer(rewardToken, feeCollector, data.feeAmount);
    }

    /// @notice Updates the epoch for a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The epoch to update
    /// @param hookData Additional data for hooks
    /// @return epoch_ The updated epoch
    function updateEpoch(uint256 campaignId, uint256 epoch, bytes calldata hookData)
        external
        nonReentrant
        validEpoch(campaignId, epoch)
        returns (uint256 epoch_)
    {
        if (epoch < campaignById[campaignId].startTimestamp) revert EPOCH_NOT_VALID();
        epoch_ = _updateEpoch(campaignId, epoch, hookData);
    }

    /// @notice Internal function to update the epoch
    /// @param campaignId The ID of the campaign
    /// @param epoch The epoch to update
    /// @param hookData Additional data for hooks
    /// @return epoch_ The updated epoch
    function _updateEpoch(uint256 campaignId, uint256 epoch, bytes calldata hookData)
        internal
        returns (uint256 epoch_)
    {
        // 1. Get the period for the current epoch
        Period storage period = _getPeriod(campaignId, epoch);
        if (period.updated) return epoch;

        // 2. Check for any pending upgrades
        _checkForUpgrade(campaignId, epoch);

        // 3. Validate the previous state if not the first period
        if (epoch >= campaignById[campaignId].startTimestamp + EPOCH_LENGTH) {
            _validatePreviousState(campaignId, epoch);

            // 4. Calculate remaining periods and total reward
            uint256 remainingPeriods = getRemainingPeriods(campaignId, epoch);
            uint256 totalRewardForRemainingPeriods = _calculateTotalReward(campaignId, epoch, remainingPeriods);

            // 5. Update the period data
            period.startTimestamp = epoch;
            period.rewardPerPeriod = remainingPeriods > 0
                ? totalRewardForRemainingPeriods.mulDiv(1, remainingPeriods)
                : totalRewardForRemainingPeriods;
        }

        // 6. Update the reward per vote
        _updateRewardPerVote(campaignId, epoch, period, hookData);

        // 7. Mark the period as updated
        period.updated = true;
        return epoch;
    }

    /// @notice Validates the previous state of a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    function _validatePreviousState(uint256 campaignId, uint256 epoch) internal view {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - EPOCH_LENGTH];
        if (!previousPeriod.updated) {
            revert PREVIOUS_STATE_MISSING();
        }
    }

    /// @notice Gets the period for a campaign and epoch
    /// @param campaignId The ID of the campaign
    /// @param epoch The epoch
    /// @return Period The period data
    function _getPeriod(uint256 campaignId, uint256 epoch) internal view returns (Period storage) {
        return periodByCampaignId[campaignId][epoch];
    }

    /// @notice Calculates the total reward for remaining periods
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    /// @param remainingPeriods The number of remaining periods
    /// @return totalReward totalReward The total reward for remaining periods
    function _calculateTotalReward(uint256 campaignId, uint256 epoch, uint256 remainingPeriods)
        internal
        view
        returns (uint256 totalReward)
    {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - EPOCH_LENGTH];
        totalReward =
            remainingPeriods > 0 ? previousPeriod.rewardPerPeriod * remainingPeriods : previousPeriod.rewardPerPeriod;

        return previousPeriod.leftover + totalReward;
    }

    /// @notice Updates the reward per vote for a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    /// @param period The period data
    /// @param hookData Additional data for hooks
    function _updateRewardPerVote(uint256 campaignId, uint256 epoch, Period storage period, bytes calldata hookData)
        internal
    {
        /// 2. Get total adjusted votes
        uint256 totalVotes = _getAdjustedVote(campaignId, epoch);

        if (totalVotes != 0) {
            Campaign storage campaign = campaignById[campaignId];

            // 4. Calculate reward per vote
            uint256 rewardPerVote = period.rewardPerPeriod.mulDiv(1e18, totalVotes);

            // 5. Cap reward per vote at max reward per vote
            if (rewardPerVote > campaign.maxRewardPerVote) {
                rewardPerVote = campaign.maxRewardPerVote;

                // 6. Calculate leftover rewards
                uint256 leftOver = period.rewardPerPeriod - rewardPerVote.mulDiv(totalVotes, 1e18);

                // 7. Handle leftover rewards
                if (hookByCampaignId[campaignId] != address(0)) {
                    // Transfer leftover to hook contract
                    SafeTransferLib.safeTransfer({
                        token: campaign.rewardToken,
                        to: hookByCampaignId[campaignId],
                        amount: leftOver
                    });
                    // Trigger the hook
                    // TODO: Not sure about this one.
                    try IHook(hookByCampaignId[campaignId]).doSomething(campaignId, epoch, leftOver, hookData) {}
                    catch {
                        delete hookByCampaignId[campaignId];
                    }
                } else {
                    // Store leftover in the period
                    period.leftover = leftOver;
                }
            }

            // 8. Save the calculated reward per vote
            period.rewardPerVote = rewardPerVote;
        }
    }

    /// @notice Calculates the adjusted total votes for a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    /// @return uint256 The adjusted total votes
    function _getAdjustedVote(uint256 campaignId, uint256 epoch) internal view returns (uint256) {
        /// 1. Get the addresses set for the campaign
        EnumerableSetLib.AddressSet storage addressesSet_ = addressesSet[campaignId];

        // 2. Get the total votes from the oracle
        uint256 totalVotes = IOracleLens(oracle).getTotalVotes(campaignById[campaignId].gauge, epoch);

        // 3. Calculate the sum of blacklisted votes
        uint256 addressesVotes;
        for (uint256 i = 0; i < addressesSet_.length(); i++) {
            addressesVotes +=
                IOracleLens(oracle).getAccountVotes(addressesSet_.at(i), campaignById[campaignId].gauge, epoch);
        }

        if (whitelistOnly[campaignId]) {
            return addressesVotes;
        }

        // 4. Return the adjusted total votes
        return totalVotes - addressesVotes;
    }

    /// @notice Creates a new incentive campaign
    /// @param chainId The chain ID for the campaign
    /// @param gauge The gauge address
    /// @param manager The manager address
    /// @param rewardToken The reward token address
    /// @param numberOfPeriods The number of periods for the campaign
    /// @param maxRewardPerVote The maximum reward per vote
    /// @param totalRewardAmount The total reward amount
    /// @param blacklist The list of blacklisted addresses
    /// @param hook The hook contract address
    /// @param isWhitelist Whether the campaign uses a whitelist
    /// @return campaignId The ID of the created campaign
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
        // Input validation
        if (numberOfPeriods < MINIMUM_PERIODS) revert INVALID_INPUT();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert ZERO_INPUT();
        if (rewardToken == address(0) || gauge == address(0)) revert ZERO_ADDRESS();

        // Check if reward token is a contract
        uint256 size;
        assembly {
            size := extcodesize(rewardToken)
        }
        if (size == 0) revert INVALID_TOKEN();

        // Transfer reward token to this contract
        SafeTransferLib.safeTransferFrom({
            token: rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

        // Generate campaign Id
        campaignId = campaignCount;
        uint256 currentEpoch_ = currentEpoch();

        // Increment campaign count
        ++campaignCount;

        // Store campaign
        campaignById[campaignId] = Campaign({
            chainId: chainId,
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            startTimestamp: currentEpoch_ + EPOCH_LENGTH,
            endTimestamp: currentEpoch_ + numberOfPeriods * EPOCH_LENGTH
        });

        // Store the hook
        hookByCampaignId[campaignId] = hook;

        // Store blacklisted or whitelisted addresses
        for (uint256 i = 0; i < blacklist.length; i++) {
            addressesSet[campaignId].add(blacklist[i]);
        }

        /// Flag if the campaign is whitelist only.
        whitelistOnly[campaignId] = isWhitelist;

        // Initialize the first period
        uint256 rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfPeriods);
        periodByCampaignId[campaignId][currentEpoch_ + EPOCH_LENGTH] = Period({
            startTimestamp: currentEpoch_ + EPOCH_LENGTH,
            rewardPerPeriod: rewardPerPeriod,
            rewardPerVote: 0,
            leftover: 0,
            updated: false
        });

        emit CampaignCreated(
            campaignId, gauge, manager, rewardToken, numberOfPeriods, maxRewardPerVote, totalRewardAmount
        );
    }

    /// @notice Manages the campaign duration, total reward amount, and max reward per vote
    /// @param campaignId The ID of the campaign
    /// @param numberOfPeriods Number of periods to add
    /// @param totalRewardAmount Total reward amount to add
    /// @param maxRewardPerVote Max reward per vote to set
    function manageCampaign(
        uint256 campaignId,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote,
        address hook,
        address[] calldata addresses
    ) external nonReentrant onlyManagerOrRemote(campaignId) {
        // Check if the campaign is ended
        if (getRemainingPeriods(campaignId, currentEpoch()) == 0) revert CAMPAIGN_ENDED();

        uint256 epoch = currentEpoch() + EPOCH_LENGTH;

        // Get the campaign
        Campaign storage campaign = campaignById[campaignId];

        // Check if there's a campaign upgrade in queue
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        if (totalRewardAmount != 0) {
            SafeTransferLib.safeTransferFrom({
                token: campaign.rewardToken,
                from: msg.sender,
                to: address(this),
                amount: totalRewardAmount
            });
        }

        uint256 updatedMaxRewardPerVote = maxRewardPerVote > 0 ? maxRewardPerVote : campaign.maxRewardPerVote;

        // Update campaign upgrade
        if (campaignUpgrade.totalRewardAmount != 0) {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaignUpgrade.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaignUpgrade.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: updatedMaxRewardPerVote,
                endTimestamp: campaignUpgrade.endTimestamp + (numberOfPeriods * EPOCH_LENGTH),
                hook: hook,
                addresses: addresses
            });
        } else {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaign.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaign.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: updatedMaxRewardPerVote,
                endTimestamp: campaign.endTimestamp + (numberOfPeriods * EPOCH_LENGTH),
                hook: hook,
                addresses: addresses
            });
        }

        // Store the campaign upgrade in queue
        campaignUpgradeById[campaignId][epoch] = campaignUpgrade;

        emit CampaignUpgradeQueued(campaignId, epoch);
    }

    /// @notice Increases the total reward amount for a campaign
    /// @param campaignId The ID of the campaign
    /// @param totalRewardAmount Total reward amount to add
    function increaseTotalRewardAmount(uint256 campaignId, uint256 totalRewardAmount) external nonReentrant {
        if (totalRewardAmount == 0) revert ZERO_INPUT();

        /// Update will be applied at the next epoch.
        uint256 epoch = currentEpoch() + EPOCH_LENGTH;
        // Get the campaign
        Campaign memory campaign = campaignById[campaignId];
        // Check if there's a campaign upgrade in queue
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        /// Cache the end timestamp.
        uint256 endTimestamp = campaign.endTimestamp;

        SafeTransferLib.safeTransferFrom({
            token: campaign.rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

        // Update campaign upgrade
        if (campaignUpgrade.totalRewardAmount != 0) {
            campaignUpgrade.totalRewardAmount += totalRewardAmount;

            /// If there's an upgrade in queue, check if the campaign duration has been increased.
            endTimestamp = campaignUpgrade.endTimestamp;
        } else {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaign.numberOfPeriods,
                totalRewardAmount: campaign.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: campaign.maxRewardPerVote,
                endTimestamp: campaign.endTimestamp,
                hook: address(0),
                addresses: new address[](0)
            });
        }

        /// If the campaign ended, it should revert.
        if (epoch >= endTimestamp) {
            revert CAMPAIGN_ENDED();
        }

        campaignUpgradeById[campaignId][epoch] = campaignUpgrade;

        emit CampaignUpgradeQueued(campaignId, epoch);
    }

    /// @notice Closes a campaign
    /// @param campaignId The ID of the campaign to close
    function closeCampaign(uint256 campaignId) external nonReentrant {
        // Get the campaign
        Campaign storage campaign = campaignById[campaignId];

        uint256 claimDeadline_ = campaign.endTimestamp + claimDeadline;
        uint256 closeDeadline_ = claimDeadline_ + closeDeadline;
        uint256 startTimestamp = campaign.startTimestamp;

        // Check if the campaign can be closed
        if (block.timestamp >= startTimestamp && block.timestamp < claimDeadline_) {
            revert CAMPAIGN_NOT_ENDED();
        }

        address receiver = campaign.manager;
        uint256 totalRewardAmount = campaign.totalRewardAmount;

        bool doDelete;
        if (block.timestamp < startTimestamp) {
            _isManagerOrRemote(campaignId);

            /// If the campaign is not started, it should be deleted.
            doDelete = true;

            /// Check if there's a campaign upgrade in queue
            CampaignUpgrade storage campaignUpgrade = campaignUpgradeById[campaignId][startTimestamp];

            /// If there's a campaign upgrade in queue, it should be applied and deleted.
            if (campaignUpgrade.totalRewardAmount != 0) {
                totalRewardAmount = campaignUpgrade.totalRewardAmount;
            }

            /// Delete the campaign upgrade.
            delete campaignUpgradeById[campaignId][startTimestamp];
        } else if (block.timestamp >= claimDeadline_ && block.timestamp < closeDeadline_) {
            _isManagerOrRemote(campaignId);
            _validatePreviousState(campaignId, campaign.endTimestamp - EPOCH_LENGTH);
        } else if (block.timestamp >= closeDeadline_) {
            receiver = feeCollector;
        }

        // Close the campaign
        _closeCampaign({
            campaignId: campaignId,
            totalRewardAmount: totalRewardAmount,
            rewardToken: campaign.rewardToken,
            receiver: receiver,
            doDelete: doDelete
        });
    }

    /// @notice Internal function to close a campaign
    /// @param campaignId The ID of the campaign
    /// @param totalRewardAmount Total reward amount
    /// @param rewardToken The reward token address
    /// @param receiver The address to receive leftover rewards
    function _closeCampaign(
        uint256 campaignId,
        uint256 totalRewardAmount,
        address rewardToken,
        address receiver,
        bool doDelete
    ) internal {
        uint256 leftOver = totalRewardAmount - totalClaimedByCampaignId[campaignId];

        // Transfer the left over to the receiver
        SafeTransferLib.safeTransfer({token: rewardToken, to: receiver, amount: leftOver});

        if (doDelete) {
            delete campaignById[campaignId];
        } else {
            /// We delete only the manager to avoid updates.
            delete campaignById[campaignId].manager;
        }

        emit CampaignClosed(campaignId);
    }

    /// @notice Checks for and applies any pending upgrades to a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    function _checkForUpgrade(uint256 campaignId, uint256 epoch) internal {
        // Get the campaign upgrade
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        // Check if there is an upgrade in queue
        if (campaignUpgrade.totalRewardAmount != 0) {
            Campaign storage campaign = campaignById[campaignId];

            if (epoch == campaign.startTimestamp) {
                periodByCampaignId[campaignId][epoch].rewardPerPeriod =
                    campaignUpgrade.totalRewardAmount.mulDiv(1, campaign.numberOfPeriods);
            } else {
                // Add to the leftover amount the newly added reward amount
                periodByCampaignId[campaignId][epoch - EPOCH_LENGTH].leftover =
                    campaignUpgrade.totalRewardAmount - campaign.totalRewardAmount;
            }

            // Update the hook.
            hookByCampaignId[campaignId] = campaignUpgrade.hook;

            /// Update the addresses.
            delete addressesSet[campaignId];

            if (campaignUpgrade.addresses.length > 0) {
                for (uint256 i = 0; i < campaignUpgrade.addresses.length; i++) {
                    addressesSet[campaignId].add(campaignUpgrade.addresses[i]);
                }
            }

            // Save new values
            campaign.endTimestamp = campaignUpgrade.endTimestamp;
            campaign.numberOfPeriods = campaignUpgrade.numberOfPeriods;
            campaign.maxRewardPerVote = campaignUpgrade.maxRewardPerVote;
            campaign.totalRewardAmount = campaignUpgrade.totalRewardAmount;

            emit CampaignUpgraded(campaignId, epoch);
        }
    }

    ////////////////////////////////////////////////////////////////
    /// --- VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////

    /// @notice Returns the number of weeks before the campaign ends
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    /// @return periodsLeft The number of periods left
    function getRemainingPeriods(uint256 campaignId, uint256 epoch) public view returns (uint256 periodsLeft) {
        Campaign storage campaign = campaignById[campaignId];
        periodsLeft = campaign.endTimestamp > epoch ? (campaign.endTimestamp - epoch) / EPOCH_LENGTH : 0;
    }

    /// @notice Gets a campaign by its ID
    /// @param campaignId The ID of the campaign
    /// @return Campaign The campaign data
    function getCampaign(uint256 campaignId) public view returns (Campaign memory) {
        return campaignById[campaignId];
    }

    /// @notice Gets a campaign upgrade by its ID and epoch
    /// @param campaignId The ID of the campaign
    /// @param epoch The epoch of the upgrade
    /// @return CampaignUpgrade The campaign upgrade data
    function getCampaignUpgrade(uint256 campaignId, uint256 epoch) public view returns (CampaignUpgrade memory) {
        return campaignUpgradeById[campaignId][epoch];
    }

    /// @notice Gets the blacklist for a campaign
    /// @param campaignId The ID of the campaign
    /// @return address[] The array of blacklisted addresses
    function getAddressesByCampaign(uint256 campaignId) public view returns (address[] memory) {
        return addressesSet[campaignId].values();
    }

    /// @notice Gets a period for a campaign
    /// @param campaignId The ID of the campaign
    /// @param periodId The ID of the period
    /// @return Period The period data
    function getPeriodPerCampaign(uint256 campaignId, uint256 periodId) public view returns (Period memory) {
        return periodByCampaignId[campaignId][periodId];
    }

    /// @notice Gets the current epoch
    /// @return uint256 The current epoch
    function currentEpoch() public view returns (uint256) {
        // 1. Get the current timestamp
        // 2. Divide it by the number of seconds in a week
        // 3. Multiply by the number of seconds in a week to round down to the start of the week
        return block.timestamp / EPOCH_LENGTH * EPOCH_LENGTH;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    /// @notice Sets the oracle address
    /// @param _oracle The new oracle address
    function setOracle(address _oracle) external onlyGovernance {
        if (_oracle == address(0)) revert ZERO_ADDRESS();
        oracle = _oracle;
    }

    /// @notice Sets the fee
    /// @param _fee The new fee (in basis points)
    function setFee(uint256 _fee) external onlyGovernance {
        // Fee cannot be higher than 10%
        if (_fee > 10e16) revert INVALID_INPUT();
        fee = _fee;
    }

    /// @notice Sets the remote address
    /// @param _remote The new remote address
    function setRemote(address _remote) external onlyGovernance {
        if (_remote == address(0)) revert ZERO_ADDRESS();
        remote = _remote;
    }

    /// @notice Sets the fee collector address
    /// @param _feeCollector The new fee collector address
    function setFeeCollector(address _feeCollector) external onlyGovernance {
        if (_feeCollector == address(0)) revert ZERO_ADDRESS();
        feeCollector = _feeCollector;
    }

    /// @notice Sets the close deadline
    /// @param _closeDeadline The new close deadline
    function setCloseDeadline(uint256 _closeDeadline) external onlyGovernance {
        closeDeadline = _closeDeadline;
    }

    /// @notice Sets the claim deadline
    /// @param _claimDeadline The new claim deadline
    function setClaimDeadline(uint256 _claimDeadline) external onlyGovernance {
        claimDeadline = _claimDeadline;
    }
}
