// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// Testing contracts & libraries
import "test/unit/votemarket/Base.t copy.sol";

contract MAnageCampaignTest is BaseCopyTest {
    uint256 public campaignId;

    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    function setUp() public override {
        BaseCopyTest.setUp();

        /// Create default campaign.
        campaignId = _createCampaign();
    }

    EnumerableSetLib.AddressSet set;
    uint256 private constant _ZERO_SENTINEL = 0xfbb67fda52d4bfb8bf;

    function testIncreaseTotalRewardAmount(uint256 amount, uint8 numberOfIncreases) public {
        vm.assume(amount < uint256(type(uint128).max));

        uint256 currentEpoch = votemarket.currentEpoch();
        uint256 remainingPeriods = votemarket.getRemainingPeriods(campaignId, currentEpoch);

        uint256 totalAmount = amount * numberOfIncreases;
        for (uint8 i = 0; i < numberOfIncreases; i++) {
            deal(address(rewardToken), creator, amount);
            rewardToken.approve(address(votemarket), amount);

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

        }

        /// Check correctness of the balance.
        assertEq(rewardToken.balanceOf(address(votemarket)), TOTAL_REWARD_AMOUNT + totalAmount);

        /// Create a new default campaign.
        campaignId = _createCampaign();

        /// Close it immediately.
        votemarket.closeCampaign(campaignId);

        /// It should trigger the modifier notClosed.
        vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector);
        votemarket.increaseTotalRewardAmount(campaignId, amount);
    }

    function testManageCampaign() public {}
}
