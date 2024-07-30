// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/src/Test.sol";
import "forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";

import "test/mocks/Hooks.sol";
import "test/unit/Base.t.sol";

contract ManageCampaignTest is BaseTest {
    function setUp() public override {
        BaseTest.setUp();

        /// Create a default campaign.
        _createCampaign();
    }

    ////////////////////////////////////////////////////////////////
    /// --- ACCESS CONTROL TESTS
    ///////////////////////////////////////////////////////////////

    function testIncreaseCampaignDurationWithInvalidManager() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        /// Increase the campaign duration.
        votemarket.manageCampaign(campaignId, 2, 0, 0);
    }

    ////////////////////////////////////////////////////////////////
    /// --- LOGIC TESTS
    ///////////////////////////////////////////////////////////////

    function testIncreaseCampaignPeriods() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Increase the campaign duration.
        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 2,
            totalRewardAmount: 0,
            maxRewardPerVote: 0
        });

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + 2);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + 2 weeks);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount);
    }

    function testIncreaseCampaignMaxRewardPerVote() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Increase the campaign duration.
        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 0,
            totalRewardAmount: 0,
            maxRewardPerVote: MAX_REWARD_PER_VOTE * 2
        });

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(MAX_REWARD_PER_VOTE, campaign.maxRewardPerVote);
        assertEq(campaignUpgrade.maxRewardPerVote, MAX_REWARD_PER_VOTE * 2);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount);
    }

    function testIncreaseCampaignTotalRewardAmount() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT * 2);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT * 2);

        /// Increase the campaign duration.
        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 0,
            totalRewardAmount: TOTAL_REWARD_AMOUNT * 2,
            maxRewardPerVote: 0
        });

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        /// It should be equal to the total reward amount + the new total reward amount.
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT * 2);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);
    }

    function testIncreaseCampaignWithAllParams() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 2,
            totalRewardAmount: TOTAL_REWARD_AMOUNT,
            maxRewardPerVote: MAX_REWARD_PER_VOTE * 2
        });

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        /// It should be equal to the total reward amount + the new total reward amount.
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + 2);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + 2 weeks);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote * 2);
    }

    function testMultipleIncreaseCampaigns() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 2,
            totalRewardAmount: TOTAL_REWARD_AMOUNT,
            maxRewardPerVote: MAX_REWARD_PER_VOTE
        });

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        /// It should be equal to the total reward amount + the new total reward amount.
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + 2);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + 2 weeks);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        votemarket.manageCampaign({
            campaignId: campaignId,
            numberOfPeriods: 2,
            totalRewardAmount: TOTAL_REWARD_AMOUNT,
            maxRewardPerVote: MAX_REWARD_PER_VOTE
        });

        /// Check the campaign.
        campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT * 2);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + 4);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + 4 weeks);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);
    }

    function testIncreaseTotalRewardAmount() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Increase the campaign duration.
        vm.expectRevert(Votemarket.ZERO_INPUT.selector);
        votemarket.increaseTotalRewardAmount(campaignId, 0);

        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);

        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Increase the campaign duration.
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);

        /// Check the campaign.
        campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(TOTAL_REWARD_AMOUNT, campaign.totalRewardAmount);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount + TOTAL_REWARD_AMOUNT * 2);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp);
        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);


    }
}
