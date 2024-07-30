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
        votemarket.increaseCampaignDuration(campaignId, 2, 0, 0);
    }

    ////////////////////////////////////////////////////////////////
    /// --- LOGIC TESTS
    ///////////////////////////////////////////////////////////////

    function testIncreaseCampaignPeriods() public {
        uint256 campaignId = votemarket.campaignCount() - 1;

        /// Increase the campaign duration.
        votemarket.increaseCampaignDuration(campaignId, 2, 0, 0);

        /// Check the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        /// Check the campaign upgrade.
        CampaignUpgrade memory campaignUpgrade = votemarket.getCampaignUpgrade(campaignId);

        assertEq(campaignUpgrade.maxRewardPerVote, campaign.maxRewardPerVote);
        assertEq(campaignUpgrade.numberOfPeriods, campaign.numberOfPeriods + 2);
        assertEq(campaignUpgrade.endTimestamp, campaign.endTimestamp + 2 weeks);
        assertEq(campaignUpgrade.totalRewardAmount, campaign.totalRewardAmount);
    }
}