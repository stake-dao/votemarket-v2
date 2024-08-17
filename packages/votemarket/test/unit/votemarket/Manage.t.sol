// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// Testing contracts & libraries
import "test/unit/votemarket/Base.t copy.sol";

contract MAnageCampaignTest is BaseCopyTest {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    uint256 public campaignId;

    function setUp() public override {
        BaseCopyTest.setUp();

        /// Create default campaign.
        campaignId = _createCampaign();
    }

    EnumerableSetLib.AddressSet set;
    uint256 private constant _ZERO_SENTINEL = 0xfbb67fda52d4bfb8bf;

    struct ManageCampaignParams {
        uint256 campaignId;
        uint8 numberOfPeriods;
        uint256 totalRewardAmount;
        uint256 maxRewardPerVote;
    }

    function testIncreaseTotalRewardAmount(uint256 amount, uint8 numberOfIncreases) public {
        vm.assume(amount < uint256(type(uint128).max));

        deal(address(rewardToken), creator, amount * numberOfIncreases);
        rewardToken.approve(address(votemarket), amount * numberOfIncreases);

        uint256 currentEpoch = votemarket.currentEpoch();
        uint256 remainingPeriods = votemarket.getRemainingPeriods(campaignId, currentEpoch);

        uint256 totalAmount = amount * numberOfIncreases;
        for (uint8 i = 0; i < numberOfIncreases; i++) {
            if (amount == 0) {
                vm.expectRevert(Votemarket.ZERO_INPUT.selector);
            } else if (remainingPeriods == 0) {
                vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
            }
            votemarket.increaseTotalRewardAmount(campaignId, amount);
        }

        if (totalAmount > 0 && numberOfIncreases > 0) {
            Campaign memory campaign = votemarket.getCampaign(campaignId);
            CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId, currentEpoch);

            assertEq(campaignUpgrade.totalRewardAmount, 0);
            assertEq(campaignUpgrade.maxRewardPerVote, 0);
            assertEq(campaignUpgrade.numberOfPeriods, 0);
            assertEq(campaignUpgrade.endTimestamp, 0);

            campaignUpgrade = votemarket.getCampaignUpgrade(campaignId, currentEpoch + 1 weeks);
            assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + totalAmount);
            assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);
            assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods);
            assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp);

            campaignUpgrade = votemarket.getCampaignUpgrade(campaignId, currentEpoch + 2 weeks);
            assertEq(campaignUpgrade.totalRewardAmount, 0);
            assertEq(campaignUpgrade.maxRewardPerVote, 0);
            assertEq(campaignUpgrade.numberOfPeriods, 0);
            assertEq(campaignUpgrade.endTimestamp, 0);

            skip(remainingPeriods * votemarket.EPOCH_LENGTH());

            vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
            votemarket.increaseTotalRewardAmount(campaignId, amount);

            /// Check correctness of the balance.
            assertEq(rewardToken.balanceOf(address(votemarket)), TOTAL_REWARD_AMOUNT + totalAmount);
        }


        /// Create a new default campaign.
        campaignId = _createCampaign();

        /// Close it immediately.
        votemarket.closeCampaign(campaignId);

        /// It should trigger the modifier notClosed.
        vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
        votemarket.increaseTotalRewardAmount(campaignId, amount);
    }

    function testManageCampaign(ManageCampaignParams memory params, uint8 numberOfIncreases) public {
        vm.assume(numberOfIncreases < 5);
        vm.assume(params.numberOfPeriods < 50);
        vm.assume(params.totalRewardAmount < uint256(type(uint128).max));
        vm.assume(params.maxRewardPerVote < uint256(type(uint128).max));

        uint256 currentEpoch = votemarket.currentEpoch();
        uint256 remainingPeriods = votemarket.getRemainingPeriods(campaignId, currentEpoch);

        deal(address(rewardToken), creator, params.totalRewardAmount * numberOfIncreases);
        rewardToken.approve(address(votemarket), params.totalRewardAmount * numberOfIncreases);

        uint totalAmount = params.totalRewardAmount * numberOfIncreases;
        uint totalNumberOfPeriods = params.numberOfPeriods * numberOfIncreases;

        for (uint8 i = 0; i < numberOfIncreases; i++) {
            if (params.campaignId != campaignId) {
                vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
            }
            votemarket.manageCampaign({
                campaignId: params.campaignId,
                numberOfPeriods: params.numberOfPeriods,
                totalRewardAmount: params.totalRewardAmount,
                maxRewardPerVote: params.maxRewardPerVote
            });
        }

        if (totalAmount > 0 && numberOfIncreases > 0 && params.campaignId == campaignId) {
            Campaign memory campaign = votemarket.getCampaign(campaignId);
            CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId, currentEpoch);

            assertEq(campaignUpgrade.totalRewardAmount, 0);
            assertEq(campaignUpgrade.maxRewardPerVote, 0);
            assertEq(campaignUpgrade.numberOfPeriods, 0);
            assertEq(campaignUpgrade.endTimestamp, 0);

            campaignUpgrade = votemarket.getCampaignUpgrade(params.campaignId, currentEpoch + 1 weeks);
            assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + totalAmount);
            assertEq(campaignUpgrade.maxRewardPerVote, params.maxRewardPerVote > 0 ? params.maxRewardPerVote : campaign.maxRewardPerVote);
            assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + totalNumberOfPeriods);
            assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + (totalNumberOfPeriods* votemarket.EPOCH_LENGTH()));

            campaignUpgrade = votemarket.getCampaignUpgrade(params.campaignId, currentEpoch + 2 weeks);
            assertEq(campaignUpgrade.totalRewardAmount, 0);
            assertEq(campaignUpgrade.maxRewardPerVote, 0);
            assertEq(campaignUpgrade.numberOfPeriods, 0);
            assertEq(campaignUpgrade.endTimestamp, 0);

            skip(remainingPeriods * votemarket.EPOCH_LENGTH());

            vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
            votemarket.manageCampaign({
                campaignId: params.campaignId,
                numberOfPeriods: params.numberOfPeriods,
                totalRewardAmount: params.totalRewardAmount,
                maxRewardPerVote: params.maxRewardPerVote
            });

            /// Check correctness of the balance.
            assertEq(rewardToken.balanceOf(address(votemarket)), TOTAL_REWARD_AMOUNT + totalAmount);
        }

        /// Create a new default campaign.
        campaignId = _createCampaign();

        /// Close it immediately.
        votemarket.closeCampaign(campaignId);

        /// It should trigger the modifier notClosed.
        vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: params.numberOfPeriods,
            totalRewardAmount: params.totalRewardAmount,
            maxRewardPerVote: params.maxRewardPerVote
        });
    }
}
