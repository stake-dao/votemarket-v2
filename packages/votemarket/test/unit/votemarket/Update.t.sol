// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract UpdateEpochTest is BaseTest {
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
        votemarket.updateEpoch(campaignId, currentEpoch);
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

        votemarket.updateEpoch(campaignId, currentEpoch);

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));

        /// Update again.
        votemarket.updateEpoch(campaignId, currentEpoch);

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        rewardPerVote = votemarket.rewardPerVoteByCampaignId(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
    }

    function testUpdateEpochForSubsequentPeriods() public {}

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
