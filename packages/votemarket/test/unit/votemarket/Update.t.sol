// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract UpdateEpochTest is BaseTest {
    using FixedPointMathLib for uint256;

    uint256 public campaignId;

    function setUp() public override {
        BaseTest.setUp();

        campaignId = _createCampaign();
    }

    function testUpdateEpochCampaignNotStarted() public {
        uint256 currentEpoch = votemarket.currentEpoch();

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        assertEq(period.startTimestamp, 0);
        assertEq(period.rewardPerPeriod, 0);
        assertEq(period.leftover, 0);

        vm.expectRevert(Votemarket.CAMPAIGN_NOT_STARTED.selector);
        votemarket.updateEpoch(campaignId, currentEpoch, "");
    }

    function testUpdateEpoch() public {
        // Skip to the start of the campaign.
        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        uint256 rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, 0);

        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));

        /// Update again.
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
    }

    function testUpdateEpochRollover() public {
        /// Rollover is triggered when the max reward per vote is reached and there's no hook associated with the campaign.
        /// Really small max reward per vote to trigger the rollover.
        uint256 maxRewardPerVote = 2;
        campaignId = _createCampaign({hook: address(0), maxRewardPerVote: maxRewardPerVote});

        // Skip to the start of the campaign.
        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        uint256 rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);

        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, 0);

        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        uint256 expectedLeftOver = period.rewardPerPeriod - maxRewardPerVote.mulDiv(TOTAL_VOTES, 1e18);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT.mulDiv(1, VALID_PERIODS));
        assertEq(period.leftover, expectedLeftOver);
        assertEq(rewardPerVote, maxRewardPerVote);

        skip(1 weeks);

        Period memory previousPeriod = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        currentEpoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        /// How much we were planning to distribute per period.
        uint256 expectedRewardPerPeriod =
            previousPeriod.rewardPerPeriod * votemarket.getRemainingPeriods(campaignId, currentEpoch);

        /// Add the leftover amount from the previous period and divide by the remaining periods.
        expectedRewardPerPeriod = (expectedRewardPerPeriod + previousPeriod.leftover)
            / votemarket.getRemainingPeriods(campaignId, currentEpoch);

        expectedLeftOver = expectedRewardPerPeriod - maxRewardPerVote.mulDiv(TOTAL_VOTES, 1e18);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.leftover, expectedLeftOver);
        assertEq(rewardPerVote, maxRewardPerVote);
    }

    function testUpdateEpochWithPreviousMissingState() public {
        /// Skip to the second period.
        skip(2 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.PREVIOUS_STATE_MISSING.selector);
        votemarket.updateEpoch(campaignId, currentEpoch, "");
    }

    function testUpdateEpochWithUpgradeInQueueFirstPeriod() public {
        deal(address(rewardToken), address(this), TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Increase the total reward amount.
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);

        uint epoch = votemarket.currentEpoch() + 1 weeks;
        Period memory period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        uint256 rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, votemarket.currentEpoch());

        assertEq(period.startTimestamp, epoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, 0);
        assertEq(period.updated, false);

        skip(1 weeks);

        uint256 expectedRewardPerPeriod = (TOTAL_REWARD_AMOUNT * 2) / VALID_PERIODS;
        votemarket.updateEpoch(campaignId, epoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, epoch);

        assertEq(period.startTimestamp, epoch);
        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, FixedPointMathLib.mulDiv(expectedRewardPerPeriod, 1e18, TOTAL_VOTES));
        assertEq(period.updated, true);

        votemarket.updateEpoch(campaignId, epoch, "");
    }

    function testUpdateEpochAfterCampaignEnd() public {}
    function testUpdateEpochWithZeroTotalVotes() public {}
    function testUpdateEpochWithLowTotalVotes() public {}

    function testUpdateEpochForWhitelistOnlyCampaign() public {}
    function testUpdateEpochWithHook() public {}
    function testUpdateEpochAfterCampaignUpgrade() public {}

    function testUpdateEpochMultipleTimes() public {}
    function testUpdateEpochWithMaximumPossibleValues() public {}

    function testUpdateEpochWithoutPreviousEpoch() public {}
    function testUpdateEpochForNonExistentCampaign() public {}
}
