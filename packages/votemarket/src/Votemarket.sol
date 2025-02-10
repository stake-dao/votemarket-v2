// SPDX-License-Identifier: BUSL-1.1
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

    /// @notice Claim window length in seconds.
    /// 6 months.
    uint256 public constant CLAIM_WINDOW_LENGTH = 24 weeks;

    /// @notice Close window length in seconds.
    /// 1 month.
    uint256 public constant CLOSE_WINDOW_LENGTH = 4 weeks;

    /// @notice Maximum number of addresses per campaign.
    uint256 public constant MAX_ADDRESSES_PER_CAMPAIGN = 50;

    /// @notice Minimum duration for a campaign.
    uint8 public immutable MINIMUM_PERIODS;

    /// @notice Epoch length in seconds.
    uint256 public immutable EPOCH_LENGTH;

    /// @notice Oracle address.
    address public immutable ORACLE;

    ////////////////////////////////////////////////////////////////
    /// --- STORAGE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice Governance address.
    address public governance;

    /// @notice Future governance address.
    address public futureGovernance;

    /// @notice Address of the remote cross-chain message handler.
    address public remote;

    /// @notice Fee receiver.
    address public feeCollector;

    /// @notice Fee.
    uint256 public fee;

    /// @notice Campaigns count.
    uint256 public campaignCount;

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

    /// @notice If campaign is closed.
    mapping(uint256 => bool) public isClosedCampaign;

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

    /// @notice Set of addresses that are whitelisted / blacklisted.
    mapping(uint256 => EnumerableSetLib.AddressSet) public addressesByCampaignId;

    ////////////////////////////////////////////////////////////////
    /// ---  EVENTS & ERRORS
    ///////////////////////////////////////////////////////////////

    /// @notice Thrown when a zero value is provided where a non-zero value is required.
    error ZERO_INPUT();

    /// @notice Thrown when a zero address is provided where a non-zero address is required.
    error ZERO_ADDRESS();

    /// @notice Thrown when an invalid token address is provided.
    error INVALID_TOKEN();

    /// @notice Thrown when an input parameter is invalid.
    error INVALID_INPUT();

    /// @notice Thrown when a claim is made for an account that is protected.
    error PROTECTED_ACCOUNT();

    /// @notice Thrown when the previous state of a campaign is missing.
    error STATE_MISSING();

    /// @notice Thrown when a claim amount exceeds the available reward amount.
    error CLAIM_AMOUNT_EXCEEDS_REWARD_AMOUNT();

    /// @notice Thrown when attempting to interact with an ended campaign.
    error CAMPAIGN_ENDED();

    /// @notice Thrown when attempting to close a campaign that has not ended.
    error CAMPAIGN_NOT_ENDED();

    /// @notice Thrown when an invalid epoch is provided.
    error EPOCH_NOT_VALID();

    /// @notice Thrown when a blacklisted address attempts an unauthorized action.
    error AUTH_BLACKLISTED();

    /// @notice Thrown when a non-manager attempts a manager-only action.
    error AUTH_MANAGER_ONLY();

    /// @notice Thrown when a non-whitelisted address attempts an action in a whitelist-only campaign.
    error AUTH_WHITELIST_ONLY();

    /// @notice Thrown when a non-governance address attempts a governance-only action.
    error AUTH_GOVERNANCE_ONLY();

    /// @notice Emitted when a claim is made.
    event Claim(uint256 indexed campaignId, address indexed account, uint256 amount, uint256 fee, uint256 epoch);

    /// @notice Emitted when a new campaign is created.
    event CampaignCreated(
        uint256 campaignId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount
    );

    /// @notice Emitted when a campaign upgrade is queued.
    event CampaignUpgradeQueued(uint256 campaignId, uint256 epoch);

    /// @notice Emitted when a campaign is upgraded.
    event CampaignUpgraded(uint256 campaignId, uint256 epoch);

    /// @notice Emitted when a campaign is closed.
    event CampaignClosed(uint256 campaignId);

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    /// @notice Ensures that only the governance address can call the function.
    modifier onlyGovernance() {
        if (msg.sender != governance) revert AUTH_GOVERNANCE_ONLY();
        _;
    }

    /// @notice Checks if an account is whitelisted or blacklisted for a campaign.
    modifier checkWhitelistOrBlacklist(uint256 campaignId, address account, uint256 epoch) {
        bool contains = addressesByCampaignId[campaignId].contains(account);
        if (whitelistOnly[campaignId] && !contains) {
            revert AUTH_WHITELIST_ONLY();
        } else if (!whitelistOnly[campaignId] && contains) {
            revert AUTH_BLACKLISTED();
        }
        _;
    }

    /// @notice Ensures that the provided epoch is valid for the given campaign.
    modifier validEpoch(uint256 campaignId, uint256 epoch) {
        if (
            epoch > block.timestamp || epoch < campaignById[campaignId].startTimestamp
                || epoch >= campaignById[campaignId].endTimestamp || epoch % EPOCH_LENGTH != 0
        ) revert EPOCH_NOT_VALID();
        _;
    }

    /// @notice Ensures that the campaign is not closed.
    modifier notClosed(uint256 campaignId) {
        if (isClosedCampaign[campaignId]) revert CAMPAIGN_ENDED();
        _;
    }

    /// @notice Ensures that only the campaign manager or remote address can call the function.
    modifier onlyManagerOrRemote(uint256 campaignId) {
        _isManagerOrRemote(campaignId);
        _;
    }

    /// @notice Check if the manager or remote is calling the function.
    /// @param campaignId The ID of the campaign.
    function _isManagerOrRemote(uint256 campaignId) internal view {
        if (msg.sender != campaignById[campaignId].manager && msg.sender != remote) revert AUTH_MANAGER_ONLY();
    }

    /// @notice Contract constructor.
    /// @param _governance The address of the governance.
    /// @param _oracle The address of the oracle.
    /// @param _feeCollector The address of the fee collector.
    /// @param _epochLength The length of an epoch in seconds.
    /// @param _minimumPeriods The minimum number of periods for a campaign.
    constructor(
        address _governance,
        address _oracle,
        address _feeCollector,
        uint256 _epochLength,
        uint8 _minimumPeriods
    ) {
        governance = _governance;
        feeCollector = _feeCollector;

        /// Default fee is 4%.
        fee = 4e16;

        ORACLE = _oracle;
        EPOCH_LENGTH = _epochLength;
        MINIMUM_PERIODS = _minimumPeriods;
    }

    ////////////////////////////////////////////////////////////////
    /// --- CLAIM LOGIC
    ///////////////////////////////////////////////////////////////

    /// @notice Allows claiming rewards for a specified account.
    /// @param campaignId The ID of the campaign.
    /// @param account The account to claim for.
    /// @param epoch The epoch to claim for.
    /// @param hookData Additional data for hooks.
    /// @return claimed The amount of rewards claimed.
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

    /// @notice Allows a user to claim rewards for a campaign.
    /// @param campaignId The ID of the campaign.
    /// @param receiver The address to receive the rewards.
    /// @param epoch The epoch for which to claim rewards.
    /// @param hookData Additional data for hooks.
    /// @return claimed The amount of rewards claimed.
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

    /// @notice Internal function to process a claim.
    /// @param data The claim data.
    /// @param hookData Additional data for hooks.
    /// @return claimed The amount of rewards claimed.
    function _claim(ClaimData memory data, bytes calldata hookData)
        internal
        notClosed(data.campaignId)
        validEpoch(data.campaignId, data.epoch)
        checkWhitelistOrBlacklist(data.campaignId, data.account, data.epoch)
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

        emit Claim(data.campaignId, data.account, data.amountToClaim, data.feeAmount, data.epoch);

        return data.amountToClaim;
    }

    /// @notice Checks if a claim is valid.
    /// @param data The claim data.
    /// @return bool True if the claim is valid, false otherwise.
    function _canClaim(ClaimData memory data) internal view returns (bool) {
        // 1. Retrieve the campaign from storage.
        Campaign storage campaign = campaignById[data.campaignId];

        // 2. Check if the vote is valid using the ORACLE.
        bool canClaimFromOracle = IOracleLens(ORACLE).isVoteValid(data.account, campaign.gauge, data.epoch);

        // 3. Check if the claim deadline has not passed.
        bool withinClaimDeadline = campaign.endTimestamp + CLAIM_WINDOW_LENGTH > block.timestamp;

        // 4. Check if the account has not claimed before or if there's a new reward available.
        bool notClaimedOrNoReward = totalClaimedByAccount[data.campaignId][data.epoch][data.account] == 0
            || periodByCampaignId[data.campaignId][data.epoch].rewardPerVote == 0;

        // 5. Return true if all conditions are met.
        return canClaimFromOracle && withinClaimDeadline && notClaimedOrNoReward;
    }

    /// @notice Calculates the claim amount and fee.
    /// @param data The claim data.
    /// @return amountToClaim The amount of rewards to claim.
    /// @return feeAmount The fee amount.
    function _calculateClaimAndFee(ClaimData memory data)
        internal
        view
        returns (uint256 amountToClaim, uint256 feeAmount)
    {
        // 1. Retrieve the campaign from storage.
        Campaign storage campaign = campaignById[data.campaignId];

        // 2. Get the account's votes from the ORACLE.
        uint256 accountVote = IOracleLens(ORACLE).getAccountVotes(data.account, campaign.gauge, data.epoch);

        // 3. Calculate the amount to claim based on the account's votes and the reward per vote.
        amountToClaim = accountVote.mulDiv(periodByCampaignId[data.campaignId][data.epoch].rewardPerVote, 1e18);

        // 4. Determine the fee percentage (custom fee for the manager or default fee).
        uint256 feeBps = customFeeByManager[campaign.manager] > 0 ? customFeeByManager[campaign.manager] : fee;

        // 5. Calculate the fee amount.
        feeAmount = amountToClaim.mulDiv(feeBps, 1e18);

        // 6. Subtract the fee from the amount to claim.
        amountToClaim -= feeAmount;
    }

    /// @notice Updates the claim state.
    /// @param data The claim data.
    function _updateClaimState(ClaimData memory data) internal {
        // 1. Update the total claimed amount for the account in this campaign and epoch.
        totalClaimedByAccount[data.campaignId][data.epoch][data.account] = data.amountToClaim + data.feeAmount;

        // 2. Update the total claimed amount for the campaign.
        totalClaimedByCampaignId[data.campaignId] += data.amountToClaim + data.feeAmount;
    }

    /// @notice Transfers tokens for a claim.
    /// @param data The claim data.
    function _transferTokens(ClaimData memory data) internal {
        // 1. Get the reward token for the campaign.
        address rewardToken = campaignById[data.campaignId].rewardToken;

        // 2. Transfer the claimed amount to the receiver.
        SafeTransferLib.safeTransfer(rewardToken, data.receiver, data.amountToClaim);

        // 3. Transfer the fee to the fee collector.
        SafeTransferLib.safeTransfer(rewardToken, feeCollector, data.feeAmount);
    }

    /// @notice Updates the epoch for a campaign.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The epoch to update.
    /// @param hookData Additional data for hooks.
    /// @return epoch_ The updated epoch.
    function updateEpoch(uint256 campaignId, uint256 epoch, bytes calldata hookData)
        external
        nonReentrant
        notClosed(campaignId)
        validEpoch(campaignId, epoch)
        returns (uint256 epoch_)
    {
        epoch_ = _updateEpoch(campaignId, epoch, hookData);
    }

    /// @notice Internal function to update the epoch.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The epoch to update.
    /// @param hookData Additional data for hooks.
    /// @return The updated epoch.
    function _updateEpoch(uint256 campaignId, uint256 epoch, bytes calldata hookData) internal returns (uint256) {
        // 1. Get the period for the current epoch.
        Period storage period = _getPeriod(campaignId, epoch);
        if (period.updated) return epoch;

        // 2. Check for any pending upgrades.
        _checkForUpgrade(campaignId, epoch);

        // 3. Validate the previous state if not the first period.
        if (epoch >= campaignById[campaignId].startTimestamp + EPOCH_LENGTH) {
            _validatePreviousState(campaignId, epoch);
        }

        // 4. Calculate remaining periods and total reward.
        uint256 remainingPeriods = getRemainingPeriods(campaignId, epoch);
        uint256 totalRewardForRemainingPeriods = _calculateTotalReward(campaignId);

        // 5. Update the period data.
        period.rewardPerPeriod = remainingPeriods > 0
            ? totalRewardForRemainingPeriods.mulDiv(1, remainingPeriods)
            : totalRewardForRemainingPeriods;

        // 6. Update the reward per vote
        _updateRewardPerVote(campaignId, epoch, period, hookData);

        // 7. Update the total distributed amount
        campaignById[campaignId].totalDistributed += (period.rewardPerPeriod - period.leftover);

        // 8. Mark the period as updated
        period.updated = true;
        return epoch;
    }

    /// @notice Validates the previous state of a campaign.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The current epoch.
    function _validatePreviousState(uint256 campaignId, uint256 epoch) internal view {
        Period storage previousPeriod = periodByCampaignId[campaignId][epoch - EPOCH_LENGTH];
        if (!previousPeriod.updated) {
            revert STATE_MISSING();
        }
    }

    /// @notice Gets the period for a campaign and epoch.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The epoch.
    /// @return Period The period data.
    function _getPeriod(uint256 campaignId, uint256 epoch) internal view returns (Period storage) {
        return periodByCampaignId[campaignId][epoch];
    }

    /// @notice Calculates the total reward for remaining periods.
    /// @param campaignId The ID of the campaign.
    /// @return totalReward The total reward for remaining periods.
    function _calculateTotalReward(uint256 campaignId) internal view returns (uint256 totalReward) {
        totalReward = campaignById[campaignId].totalRewardAmount - campaignById[campaignId].totalDistributed;
        return totalReward;
    }

    /// @notice Updates the reward per vote for a campaign.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The current epoch.
    /// @param period The period data.
    /// @param hookData Additional data for hooks.
    function _updateRewardPerVote(uint256 campaignId, uint256 epoch, Period storage period, bytes calldata hookData)
        internal
    {
        // 1. Get total adjusted votes
        uint256 totalVotes = _getAdjustedVote(campaignId, epoch);

        // 2. If no votes, rollover the leftover to the next epoch.
        if (totalVotes == 0) {
            period.leftover = period.rewardPerPeriod;
            return;
        }

        Campaign storage campaign = campaignById[campaignId];

        // 3. Calculate reward per vote
        uint256 rewardPerVote = period.rewardPerPeriod.mulDiv(1e18, totalVotes);

        // 4. Cap reward per vote at max reward per vote
        if (rewardPerVote > campaign.maxRewardPerVote) {
            rewardPerVote = campaign.maxRewardPerVote;

            // 5. Calculate leftover rewards
            uint256 leftOver = period.rewardPerPeriod - rewardPerVote.mulDiv(totalVotes, 1e18);

            // 6. Handle leftover rewards
            address hook = campaign.hook;
            if (hook != address(0)) {
                // Transfer leftover to hook contract
                SafeTransferLib.safeTransfer({token: campaign.rewardToken, to: hook, amount: leftOver});
                // Trigger the hook
                hook.call(
                    abi.encodeWithSelector(
                        IHook.doSomething.selector,
                        campaignId,
                        campaign.chainId,
                        campaign.rewardToken,
                        epoch,
                        leftOver,
                        hookData
                    )
                );

                // Consider the leftover as claimed.
                totalClaimedByCampaignId[campaignId] += leftOver;
            } else {
                // Store leftover in the period.
                period.leftover += leftOver;
            }
        }

        // 6. Save the calculated reward per vote.
        period.rewardPerVote = rewardPerVote;
    }

    /// @notice Calculates the adjusted total votes for a campaign.
    /// @param campaignId The ID of the campaign.
    /// @param epoch The current epoch.
    /// @return The adjusted total votes.
    function _getAdjustedVote(uint256 campaignId, uint256 epoch) internal view returns (uint256) {
        // 1. Get the addresses set for the campaign
        EnumerableSetLib.AddressSet storage addressesSet_ = addressesByCampaignId[campaignId];

        // 2. Get the total votes from the ORACLE
        uint256 totalVotes = IOracleLens(ORACLE).getTotalVotes(campaignById[campaignId].gauge, epoch);

        // 3. Calculate the sum of blacklisted votes.
        uint256 addressesVotes;
        for (uint256 i = 0; i < addressesSet_.length(); i++) {
            addressesVotes +=
                IOracleLens(ORACLE).getAccountVotes(addressesSet_.at(i), campaignById[campaignId].gauge, epoch);
        }

        if (whitelistOnly[campaignId]) {
            return addressesVotes;
        }

        // 4. Return the adjusted total votes.
        return totalVotes - addressesVotes;
    }

    /// @notice Creates a new incentive campaign.
    /// @param chainId The chain ID for the campaign.
    /// @param gauge The gauge address.
    /// @param manager The manager address.
    /// @param rewardToken The reward token address.
    /// @param numberOfPeriods The number of periods for the campaign.
    /// @param maxRewardPerVote The maximum reward per vote.
    /// @param totalRewardAmount The total reward amount.
    /// @param addresses The list of addresses blacklist or whitelist.
    /// @param hook The hook contract address.
    /// @param isWhitelist Whether the campaign uses a whitelist.
    /// @return campaignId The ID of the created campaign.
    function createCampaign(
        uint256 chainId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] calldata addresses,
        address hook,
        bool isWhitelist
    ) external nonReentrant returns (uint256 campaignId) {
        // 1. Input validation
        if (numberOfPeriods < MINIMUM_PERIODS) revert INVALID_INPUT();
        if (totalRewardAmount == 0 || maxRewardPerVote == 0) revert ZERO_INPUT();
        if (rewardToken == address(0) || gauge == address(0)) revert ZERO_ADDRESS();
        if (addresses.length > MAX_ADDRESSES_PER_CAMPAIGN) revert INVALID_INPUT();

        // 2. Check if reward token is a contract
        uint256 size;
        assembly {
            size := extcodesize(rewardToken)
        }
        if (size == 0) revert INVALID_TOKEN();

        // 3. Transfer reward token to this contract
        SafeTransferLib.safeTransferFrom({
            token: rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

        // 4. Generate campaign Id and get current epoch
        campaignId = campaignCount;

        // 5. Increment campaign count
        ++campaignCount;

        uint256 startTimestamp = currentEpoch() + EPOCH_LENGTH;

        // 6. Store campaign
        campaignById[campaignId] = Campaign({
            chainId: chainId,
            gauge: gauge,
            manager: manager,
            rewardToken: rewardToken,
            numberOfPeriods: numberOfPeriods,
            maxRewardPerVote: maxRewardPerVote,
            totalRewardAmount: totalRewardAmount,
            totalDistributed: 0,
            startTimestamp: startTimestamp,
            endTimestamp: startTimestamp + numberOfPeriods * EPOCH_LENGTH,
            hook: hook
        });

        /// 7. Set the reward per period for the first period.
        periodByCampaignId[campaignId][startTimestamp].rewardPerPeriod = totalRewardAmount.mulDiv(1, numberOfPeriods);

        /// 8. Add the addresses to the campaign.
        EnumerableSetLib.AddressSet storage addresses_ = addressesByCampaignId[campaignId];
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0)) continue;
            addresses_.add(addresses[i]);
        }

        // 9. Flag if the campaign is whitelist only
        whitelistOnly[campaignId] = isWhitelist;

        emit CampaignCreated(
            campaignId, gauge, manager, rewardToken, numberOfPeriods, maxRewardPerVote, totalRewardAmount
        );
    }

    /// @notice Manages the campaign duration, total reward amount, and max reward per vote.
    /// @param campaignId The ID of the campaign.
    /// @param numberOfPeriods Number of periods to add.
    /// @param totalRewardAmount Total reward amount to add.
    /// @param maxRewardPerVote Max reward per vote to set.
    function manageCampaign(
        uint256 campaignId,
        uint8 numberOfPeriods,
        uint256 totalRewardAmount,
        uint256 maxRewardPerVote
    ) external nonReentrant onlyManagerOrRemote(campaignId) notClosed(campaignId) {
        uint256 epoch = currentEpoch();
        // 1. Check if the campaign is ended.
        if (getRemainingPeriods(campaignId, epoch) <= 1) revert CAMPAIGN_ENDED();

        // 2. Get the campaign.
        Campaign storage campaign = campaignById[campaignId];

        if (campaign.startTimestamp <= epoch && !periodByCampaignId[campaignId][epoch].updated) {
            revert STATE_MISSING();
        }

        // 3. Calculate the next epoch.
        epoch += EPOCH_LENGTH;

        // 4. Check if there's a campaign upgrade in queue for this epoch.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        // 5. Transfer additional reward tokens if needed.
        if (totalRewardAmount != 0) {
            SafeTransferLib.safeTransferFrom({
                token: campaign.rewardToken,
                from: msg.sender,
                to: address(this),
                amount: totalRewardAmount
            });
        }

        // 6. Update campaign upgrade
        if (campaignUpgrade.totalRewardAmount != 0) {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaignUpgrade.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaignUpgrade.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: maxRewardPerVote > 0 ? maxRewardPerVote : campaignUpgrade.maxRewardPerVote,
                endTimestamp: campaignUpgrade.endTimestamp + (numberOfPeriods * EPOCH_LENGTH)
            });
        } else {
            campaignUpgrade = CampaignUpgrade({
                numberOfPeriods: campaign.numberOfPeriods + numberOfPeriods,
                totalRewardAmount: campaign.totalRewardAmount + totalRewardAmount,
                maxRewardPerVote: maxRewardPerVote > 0 ? maxRewardPerVote : campaign.maxRewardPerVote,
                endTimestamp: campaign.endTimestamp + (numberOfPeriods * EPOCH_LENGTH)
            });
        }

        // 7. Store the campaign upgrade in queue
        campaignUpgradeById[campaignId][epoch] = campaignUpgrade;

        emit CampaignUpgradeQueued(campaignId, epoch);
    }

    /// @notice Updates the manager for a campaign
    /// @param campaignId The ID of the campaign
    /// @param newManager The new manager address
    function updateManager(uint256 campaignId, address newManager)
        external
        nonReentrant
        onlyManagerOrRemote(campaignId)
        notClosed(campaignId)
    {
        campaignById[campaignId].manager = newManager;
    }

    /// @notice Increases the total reward amount for a campaign
    /// @param campaignId The ID of the campaign
    /// @param totalRewardAmount Total reward amount to add
    function increaseTotalRewardAmount(uint256 campaignId, uint256 totalRewardAmount)
        external
        nonReentrant
        notClosed(campaignId)
    {
        uint256 epoch = currentEpoch();
        // 1. Check for zero input and check if the campaign is ended.
        if (totalRewardAmount == 0) revert ZERO_INPUT();
        if (getRemainingPeriods(campaignId, epoch) <= 1) revert CAMPAIGN_ENDED();

        // 2. Check if there's a campaign upgrade in queue for the previous epoch.
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];
        if (campaignUpgrade.totalRewardAmount != 0 && !periodByCampaignId[campaignId][epoch].updated) {
            revert STATE_MISSING();
        }

        // 3. Calculate the next epoch
        epoch += EPOCH_LENGTH;

        // 4. Get the campaign
        Campaign storage campaign = campaignById[campaignId];

        // 5. Check if there's a campaign upgrade in queue
        campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        // 6. Transfer additional reward tokens
        SafeTransferLib.safeTransferFrom({
            token: campaign.rewardToken,
            from: msg.sender,
            to: address(this),
            amount: totalRewardAmount
        });

        // 7. Update campaign upgrade
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

        // 8. Store the updated campaign upgrade
        campaignUpgradeById[campaignId][epoch] = campaignUpgrade;

        emit CampaignUpgradeQueued(campaignId, epoch);
    }

    /// @notice Closes a campaign
    /// @param campaignId The ID of the campaign to close
    function closeCampaign(uint256 campaignId) external notClosed(campaignId) nonReentrant {
        // 1. Get campaign data and calculate time windows
        Campaign storage campaign = campaignById[campaignId];
        uint256 currentTime = block.timestamp;
        uint256 claimWindow = campaign.endTimestamp + CLAIM_WINDOW_LENGTH;
        uint256 closeWindow = claimWindow + CLOSE_WINDOW_LENGTH;
        address receiver = campaign.manager;

        // 2. Handle different closing scenarios
        if (currentTime < campaign.startTimestamp) {
            // 2a. Campaign hasn't started yet
            _isManagerOrRemote(campaignId);
            _checkForUpgrade(campaignId, campaign.startTimestamp);
        } else if (currentTime < claimWindow) {
            // 2b. Campaign is ongoing or within claim window
            revert CAMPAIGN_NOT_ENDED();
        } else if (currentTime < closeWindow) {
            // 2c. Within close window, only manager can close
            _isManagerOrRemote(campaignId);
            _validatePreviousState(campaignId, campaign.endTimestamp);
        } else {
            // 2d. After close window, anyone can close and funds go to fee collector
            _validatePreviousState(campaignId, campaign.endTimestamp);
            receiver = feeCollector;
        }

        // 3. Close the campaign
        _closeCampaign(campaignId, campaign.totalRewardAmount, campaign.rewardToken, receiver);
    }

    /// @notice Internal function to close a campaign
    /// @param campaignId The ID of the campaign
    /// @param totalRewardAmount Total reward amount
    /// @param rewardToken The reward token address
    /// @param receiver The address to receive leftover rewards
    function _closeCampaign(uint256 campaignId, uint256 totalRewardAmount, address rewardToken, address receiver)
        internal
    {
        // 1. Calculate leftover rewards
        uint256 leftOver = totalRewardAmount - totalClaimedByCampaignId[campaignId];

        // 2. Transfer leftover rewards to the receiver
        SafeTransferLib.safeTransfer({token: rewardToken, to: receiver, amount: leftOver});

        // 3. Update the total claimed amount
        totalClaimedByCampaignId[campaignId] = totalRewardAmount;

        // 4. Set the campaign as closed
        isClosedCampaign[campaignId] = true;

        emit CampaignClosed(campaignId);
    }

    /// @notice Checks for and applies any pending upgrades to a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The current epoch
    function _checkForUpgrade(uint256 campaignId, uint256 epoch) internal {
        // 1. Get the campaign upgrade
        CampaignUpgrade memory campaignUpgrade = campaignUpgradeById[campaignId][epoch];

        // 2. Check if there is an upgrade in queue
        if (campaignUpgrade.totalRewardAmount != 0) {
            // 3. Get the campaign
            Campaign storage campaign = campaignById[campaignId];

            // 7. Save new campaign values
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
        return addressesByCampaignId[campaignId].values();
    }

    /// @notice Gets a period for a campaign
    /// @param campaignId The ID of the campaign
    /// @param epoch The epoch of the period
    /// @return Period The period data
    function getPeriodPerCampaign(uint256 campaignId, uint256 epoch) public view returns (Period memory) {
        return periodByCampaignId[campaignId][epoch];
    }

    /// @notice Gets the current epoch
    /// @return uint256 The current epoch
    function currentEpoch() public view returns (uint256) {
        return block.timestamp / EPOCH_LENGTH * EPOCH_LENGTH;
    }

    ////////////////////////////////////////////////////////////////
    /// --- SETTERS
    ///////////////////////////////////////////////////////////////

    /// @notice Sets if an account is protected
    /// @param _account The account address
    /// @param _isProtected The new is protected value
    function setIsProtected(address _account, bool _isProtected) external onlyGovernance {
        isProtected[_account] = _isProtected;
    }

    /// @notice Sets the remote address
    /// @param _remote The new remote address
    function setRemote(address _remote) external onlyGovernance {
        // 1. Check for zero address
        if (_remote == address(0)) revert ZERO_ADDRESS();

        // 2. Set the new remote address
        remote = _remote;
    }

    /// @notice Sets the fee
    /// @param _fee The new fee (in basis points)
    function setFee(uint256 _fee) external onlyGovernance {
        if (_fee > 10e16) revert INVALID_INPUT();
        fee = _fee;
    }

    /// @notice Sets a custom fee for a manager
    /// @param _account The manager address
    /// @param _fee The new fee (in basis points)
    function setCustomFee(address _account, uint256 _fee) external onlyGovernance {
        if (_fee > 10e16) revert INVALID_INPUT();
        customFeeByManager[_account] = _fee;
    }

    /// @notice Sets a recipient for the sender
    /// @param _recipient The new recipient address
    function setRecipient(address _recipient) external {
        recipients[msg.sender] = _recipient;
    }

    /// @notice Sets a recipient for an account
    /// @param _account The account address
    /// @param _recipient The new recipient address
    function setRecipient(address _account, address _recipient) external onlyGovernance {
        recipients[_account] = _recipient;
    }

    /// @notice Sets the fee collector address
    /// @param _feeCollector The new fee collector address
    function setFeeCollector(address _feeCollector) external onlyGovernance {
        if (_feeCollector == address(0)) revert ZERO_ADDRESS();
        feeCollector = _feeCollector;
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
