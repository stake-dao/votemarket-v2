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

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.updateEpoch(campaignId, currentEpoch, "");
    }

    function testUpdateEpoch() public {
        // Skip to the start of the campaign.
        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, 0);

        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));

        /// Update again.
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
    }

    function testUpdateEpochRollover() public {
        /// Rollover is triggered when the max reward per vote is reached and there's no hook associated with the campaign.
        /// Really small max reward per vote to trigger the rollover.
        uint256 maxRewardPerVote = 2;
        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: maxRewardPerVote,
            addresses: blacklist,
            whitelist: false
        });

        // Skip to the start of the campaign.
        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);

        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, 0);

        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        uint256 expectedLeftOver = period.rewardPerPeriod - maxRewardPerVote.mulDiv(TOTAL_VOTES, 1e18);

        assertEq(period.startTimestamp, currentEpoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT.mulDiv(1, VALID_PERIODS));
        assertEq(period.leftover, expectedLeftOver);
        assertEq(period.rewardPerVote, maxRewardPerVote);

        skip(1 weeks);

        Period memory previousPeriod = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

        currentEpoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

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
        assertEq(period.rewardPerVote, maxRewardPerVote);
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

        uint256 epoch = votemarket.currentEpoch() + 1 weeks;
        Period memory period = votemarket.getPeriodPerCampaign(campaignId, epoch);

        assertEq(period.startTimestamp, epoch);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, 0);
        assertEq(period.updated, false);

        skip(1 weeks);

        uint256 expectedRewardPerPeriod = (TOTAL_REWARD_AMOUNT * 2) / VALID_PERIODS;
        votemarket.updateEpoch(campaignId, epoch, "");

        period = votemarket.getPeriodPerCampaign(campaignId, epoch);

        assertEq(period.startTimestamp, epoch);
        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(expectedRewardPerPeriod, 1e18, TOTAL_VOTES));
        assertEq(period.updated, true);

        votemarket.updateEpoch(campaignId, epoch, "");
    }

    function testUpdateEpochAfterCampaignEnd() public {
        skip(VALID_PERIODS * 1 weeks);
        skip(votemarket.claimDeadline());

        vm.expectRevert(Votemarket.PREVIOUS_STATE_MISSING.selector);
        votemarket.closeCampaign(campaignId);

        uint256 epoch = votemarket.currentEpoch();
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.updateEpoch(campaignId, epoch, "");

        vm.expectRevert(Votemarket.PREVIOUS_STATE_MISSING.selector);
        votemarket.updateEpoch(campaignId, campaign.endTimestamp - 1 weeks, "");

        votemarket.updateEpoch(campaignId, campaign.startTimestamp, "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, campaign.startTimestamp);
        assertEq(period.startTimestamp, campaign.startTimestamp);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);

        votemarket.updateEpoch(campaignId, campaign.startTimestamp + 1 weeks, "");

        period = votemarket.getPeriodPerCampaign(campaignId, campaign.startTimestamp + 1 weeks);
        assertEq(period.startTimestamp, campaign.startTimestamp + 1 weeks);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);

        votemarket.updateEpoch(campaignId, campaign.startTimestamp + 2 weeks, "");

        vm.expectRevert();
        /// The campaign is over. Meaning there's no periods left. Meaning division by zero.
        votemarket.updateEpoch(campaignId, campaign.startTimestamp + 3 weeks, "");
        votemarket.closeCampaign(campaignId);
    }

    function testUpdateEpochWithZeroTotalVotes() public {
        skip(1 weeks);
        oracleLens.setTotalVotes(GAUGE, votemarket.currentEpoch(), 0);
        votemarket.updateEpoch(campaignId, votemarket.currentEpoch(), "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, votemarket.currentEpoch());
        assertEq(period.startTimestamp, votemarket.currentEpoch());
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);

        /// Even it no votes, the reward per vote should be 1.
        assertEq(period.rewardPerVote, 1);
    }

    function testUpdateEpochWithLowTotalVotes() public {
        skip(1 weeks);
        uint256 lowTotalVotes = 10;
        oracleLens.setTotalVotes(GAUGE, votemarket.currentEpoch(), lowTotalVotes);
        votemarket.updateEpoch(campaignId, votemarket.currentEpoch(), "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, votemarket.currentEpoch());

        assertEq(period.startTimestamp, votemarket.currentEpoch());
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);

        assertEq(period.rewardPerVote, MAX_REWARD_PER_VOTE);
    }

    function testUpdateEpochForWhitelistOnlyCampaign() public {
        // Create a whitelist-only campaign
        address[] memory whitelist = new address[](1);
        uint256 maxRewardPerVote = 123e18;
        whitelist[0] = address(this);
        uint256 whitelistCampaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: maxRewardPerVote,
            addresses: whitelist,
            whitelist: true
        });

        skip(1 weeks);
        votemarket.updateEpoch(whitelistCampaignId, votemarket.currentEpoch(), "");

        Period memory period = votemarket.getPeriodPerCampaign(whitelistCampaignId, votemarket.currentEpoch());
        uint256 expectedRewardPerVote = period.rewardPerPeriod.mulDiv(1e18, ACCOUNT_VOTES);

        assertEq(period.startTimestamp, votemarket.currentEpoch());
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);
        assertEq(period.rewardPerVote, expectedRewardPerVote);
    }

    function testUpdateEpochWithHook() public {
        // Deploy a mock hook contract
        MockHook mockHook = new MockHook();

        uint256 maxRewardPerVote = 0.1e18;
        uint256 hookCampaignId = _createCampaign({
            hook: address(mockHook),
            maxRewardPerVote: maxRewardPerVote,
            addresses: blacklist,
            whitelist: false
        });

        skip(1 weeks);
        votemarket.updateEpoch(hookCampaignId, votemarket.currentEpoch(), "");

        Period memory period = votemarket.getPeriodPerCampaign(hookCampaignId, votemarket.currentEpoch());

        assertEq(period.startTimestamp, votemarket.currentEpoch());
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.updated, true);
        assertEq(period.rewardPerVote, maxRewardPerVote);

        uint256 adjustedRewardPerPeriod = maxRewardPerVote.mulDiv(TOTAL_VOTES, 1e18);
        uint256 leftOver = period.rewardPerPeriod - adjustedRewardPerPeriod;

        /// By 2, because there's already a campaign created at the setup.
        assertEq(rewardToken.balanceOf(address(votemarket)), (TOTAL_REWARD_AMOUNT * 2) - leftOver);
        assertEq(rewardToken.balanceOf(address(mockHook)), leftOver);
    }

    function testUpdateEpochMultipleTimes() public {
        skip(1 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        for (uint256 i = 0; i < 3; i++) {
            votemarket.updateEpoch(campaignId, currentEpoch, "");

            Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);

            assertEq(period.startTimestamp, currentEpoch);
            assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
            assertEq(period.leftover, 0);
            assertEq(period.updated, true);
            assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
        }
    }

    function testUpdateEpochWithoutPreviousEpoch() public {
        skip(2 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.PREVIOUS_STATE_MISSING.selector);
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        // Update the first epoch
        votemarket.updateEpoch(campaignId, currentEpoch - 1 weeks, "");

        // Now updating the current epoch should work
        votemarket.updateEpoch(campaignId, currentEpoch, "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
        assertEq(period.updated, true);
    }

    function testUpdateEpochForNonExistentCampaign() public {
        uint256 nonExistentCampaignId = 9999;
        uint256 currentEpoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.updateEpoch(nonExistentCampaignId, currentEpoch, "");
    }
}
