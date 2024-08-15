// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// Testing contracts & libraries
import "test/unit/votemarket/Base.t.sol";

contract CloseCampaignTest is BaseTest {
    address feeCollector = address(0xCAFE);

    function setUp() public override {
        BaseTest.setUp();

        /// Create a default campaign.
        _createCampaign();

        votemarket.setClaimDeadline(3 weeks);
        votemarket.setCloseDeadline(3 weeks);

        votemarket.setFeeCollector(feeCollector);
    }

    function testCloseNonExistentCampaign() public {
        uint256 campaignId = votemarket.campaignCount();

        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);
    }

    function testCloseCampaignThatHasNotStarted() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// With random address.
        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        /// With Manager.
        votemarket.closeCampaign(campaignId);

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        uint256 balance = rewardToken.balanceOf(address(votemarket));
        uint256 managerBalance = rewardToken.balanceOf(creator);

        assertEq(campaign.manager, address(0));
        assertEq(balance, 0);
        assertEq(managerBalance, TOTAL_REWARD_AMOUNT);

        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        /// Since the campaign is deleted, it should revert with EPOCH_NOT_VALID as start timestamp = 0.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));
    }

    function testCloseCampaignThatHasNotStartedWithAnUpgradeInQueue() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), address(this), TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Increase the total reward amount.
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);

        /// With random address.
        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        /// With Manager.
        votemarket.closeCampaign(campaignId);

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        uint256 balance = rewardToken.balanceOf(address(votemarket));
        uint256 managerBalance = rewardToken.balanceOf(creator);

        assertEq(campaign.manager, address(0));
        assertEq(balance, 0);
        assertEq(managerBalance, TOTAL_REWARD_AMOUNT * 2);

        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        /// Since the campaign is deleted, it should revert with EPOCH_NOT_VALID as start timestamp = 0.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));
    }

    function testCloseOngoingCampaign() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Skip to the start of the campaign.
        skip(1 weeks);

        /// Close the campaign.
        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);

        /// Even with random address, it should revert with CAMPAIGN_NOT_ENDED.
        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);
    }

    function testCloseEndedCampaignInClaimDeadline() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Skip to the end of the campaign.
        /// 1 week before the start + 2 weeks for the campaign + 1 week to the end.
        skip(4 weeks);

        /// We're in the claim deadline period, so it should revert with CAMPAIGN_NOT_ENDED.
        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);

        _updateEpochs(campaignId);

        /// Skip to the end of the claim deadline.
        skip(3 weeks);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        votemarket.closeCampaign(campaignId);

        /// Try to close the campaign again.
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        /// Get the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        uint256 balance = rewardToken.balanceOf(address(votemarket));
        uint256 managerBalance = rewardToken.balanceOf(creator);

        assertEq(campaign.manager, address(0));
        assertEq(balance, 0);
        assertEq(managerBalance, TOTAL_REWARD_AMOUNT);
    }

    function testCloseEndedCampaignInCloseDeadline() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Skip to the end of the campaign.
        /// 1 week before the start + 2 weeks for the campaign + 1 week to the end.
        skip(4 weeks);

        /// We're in the close deadline period, so it should revert with CAMPAIGN_NOT_ENDED.
        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);

        _updateEpochs(campaignId);

        /// Skip to the end of the close deadline.
        skip(3 weeks);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        /// Skip to the end of the close deadline.
        skip(3 weeks);

        vm.prank(address(0xBEEF));
        /// The call is now permitted, and callable by anyone.
        votemarket.closeCampaign(campaignId);

        uint256 balance = rewardToken.balanceOf(address(votemarket));
        uint256 managerBalance = rewardToken.balanceOf(creator);
        uint256 feeBalance = rewardToken.balanceOf(feeCollector);

        assertEq(balance, 0);
        assertEq(managerBalance, 0);
        assertEq(feeBalance, TOTAL_REWARD_AMOUNT);
    }

    function testCloseCampaignWithAnUpgradeInQueue() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        deal(address(rewardToken), address(this), TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Increase the total reward amount.
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);

        /// Skip to the end of the campaign.
        /// 1 week before the start + 2 weeks for the campaign + 1 week to the end.
        skip(4 weeks);

        /// We're in the claim deadline period, so it should revert with CAMPAIGN_NOT_ENDED.
        vm.expectRevert(Votemarket.CAMPAIGN_NOT_ENDED.selector);
        votemarket.closeCampaign(campaignId);

        /// Skip to the end of the claim deadline.
        skip(3 weeks);

        vm.expectRevert(Votemarket.PREVIOUS_STATE_MISSING.selector);
        votemarket.closeCampaign(campaignId);

        _updateEpochs(campaignId);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_MANAGER_ONLY.selector);
        votemarket.closeCampaign(campaignId);

        votemarket.closeCampaign(campaignId);

        uint256 balance = rewardToken.balanceOf(address(votemarket));
        uint256 managerBalance = rewardToken.balanceOf(creator);

        assertEq(balance, 0);
        assertEq(managerBalance, TOTAL_REWARD_AMOUNT * 2);
    }
    /// TODO: Test the close campaign with claimed rewards.
}
