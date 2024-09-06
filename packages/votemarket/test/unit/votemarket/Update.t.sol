// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract UpdateEpochTest is BaseTest {
    using FixedPointMathLib for uint256;

    uint256 public campaignId;
    address voter = address(0xBEEF);

    function setUp() public override {
        BaseTest.setUp();

        /// Create a default campaign.
        campaignId = _createCampaign();
    }

    struct ManageCampaignParams {
        uint8 numberOfPeriods;
        uint256 totalRewardAmount;
        uint256 maxRewardPerVote;
    }

    struct MockedOracleData {
        uint256 totalVotes;
        uint256 accountVotes;
    }

    struct MockedOracleWhitelistData {
        address[] addresses;
        uint128[] accountVotes;
    }

    function testUpdateEpoch(ManageCampaignParams memory params, MockedOracleData memory data) public {
        uint256 epochLenght = votemarket.EPOCH_LENGTH();
        Campaign memory campaign = votemarket.getCampaign(campaignId);

        vm.assume(params.numberOfPeriods < 50);
        vm.assume(params.totalRewardAmount < uint256(type(uint128).max));
        vm.assume(params.maxRewardPerVote < uint256(type(uint128).max));

        vm.assume(data.accountVotes < data.totalVotes);
        vm.assume(data.totalVotes < uint256(type(uint128).max));

        /// Round down to the nearest epoch.
        uint256 epoch = block.timestamp;
        bytes memory hookData = abi.encode(epoch);

        /// Block timestamp is not a valid epoch.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.updateEpoch(campaignId, epoch, hookData);

        /// We round down to the nearest epoch.
        epoch = epoch / epochLenght * epochLenght;
        /// Still not a valid epoch because it's not the start of the campaign.
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.updateEpoch(campaignId, epoch, hookData);

        deal(address(rewardToken), address(this), TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        /// Trigger the manager action.
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT);
        TOTAL_REWARD_AMOUNT = TOTAL_REWARD_AMOUNT * 2;

        /// Skip to the start of the campaign.
        skip(epochLenght);
        epoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, epoch, hookData);

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        Period memory previousPeriod = votemarket.getPeriodPerCampaign(campaignId, epoch - epochLenght);

        /// Since it's the first epoch, there should be no leftover, reward per period should be updated on the go.
        assertEq(previousPeriod.leftover, 0);
        assertEq(previousPeriod.updated, false);
        assertEq(previousPeriod.rewardPerPeriod, 0);
        assertEq(previousPeriod.rewardPerVote, 0);

        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
        assertEq(period.updated, true);

        /// Mock the oracle data.
        oracleLens.setTotalVotes(campaign.gauge, epoch, data.totalVotes);
        oracleLens.setAccountVotes(voter, campaign.gauge, epoch, data.accountVotes);

        deal(address(rewardToken), address(this), params.totalRewardAmount);
        rewardToken.approve(address(votemarket), params.totalRewardAmount);

        /// Trigger the manager action.
        votemarket.manageCampaign(campaignId, params.numberOfPeriods, params.totalRewardAmount, params.maxRewardPerVote);

        /// Trigger the update.
        votemarket.updateEpoch(campaignId, epoch, hookData);

        /// Nothing should have changed.
        period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        campaign = votemarket.getCampaign(campaignId);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, FixedPointMathLib.mulDiv(period.rewardPerPeriod, 1e18, TOTAL_VOTES));
        assertEq(period.updated, true);

        /// Skip to the next epoch.
        skip(epochLenght);
        epoch = votemarket.currentEpoch();

        period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        assertEq(period.rewardPerPeriod, 0);
        assertEq(period.leftover, 0);
        assertEq(period.rewardPerVote, 0);
        assertEq(period.updated, false);

        uint256 distributed = campaign.totalDistributed;

        /// Trigger the update.
        votemarket.updateEpoch(campaignId, epoch, hookData);

        campaign = votemarket.getCampaign(campaignId);
        assertEq(
            campaign.endTimestamp, campaign.startTimestamp + (params.numberOfPeriods + VALID_PERIODS) * epochLenght
        );
        assertEq(campaign.totalRewardAmount, TOTAL_REWARD_AMOUNT + params.totalRewardAmount);
        assertEq(
            campaign.maxRewardPerVote, params.maxRewardPerVote > 0 ? params.maxRewardPerVote : campaign.maxRewardPerVote
        );

        previousPeriod = votemarket.getPeriodPerCampaign(campaignId, epoch - epochLenght);
        assertEq(previousPeriod.leftover, 0);

        uint256 remainingPeriods = votemarket.getRemainingPeriods(campaignId, epoch);

        uint256 balanceVM = rewardToken.balanceOf(address(votemarket));
        uint256 balanceHook = rewardToken.balanceOf(address(HOOK));
        assertEq(TOTAL_REWARD_AMOUNT + params.totalRewardAmount, balanceVM + balanceHook);

        uint256 totalRewardAmount = campaign.totalRewardAmount - distributed;

        uint256 expectedRewardPerPeriod = totalRewardAmount.mulDiv(1, remainingPeriods);
        uint256 expectedRewardPerVote = expectedRewardPerPeriod.mulDiv(1e18, data.totalVotes);

        if (expectedRewardPerVote > campaign.maxRewardPerVote) {
            expectedRewardPerVote = campaign.maxRewardPerVote;

            uint256 leftOver = expectedRewardPerPeriod - expectedRewardPerVote.mulDiv(data.totalVotes, 1e18);

            assertEq(votemarket.totalClaimedByCampaignId(campaignId), leftOver);
            assertEq(rewardToken.balanceOf(address(HOOK)), leftOver);
        }

        period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        assertEq(period.updated, true);
        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.rewardPerVote, expectedRewardPerVote, "Reward per vote should be set");

        /// Skip two epoch.
        skip(2 * epochLenght);
        epoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.STATE_MISSING.selector);
        votemarket.updateEpoch(campaignId, epoch, hookData);
    }

    function testUpdateEpochWithWrongHook() public {
        uint256 epochLenght = votemarket.EPOCH_LENGTH();
        uint256 epoch = votemarket.currentEpoch();

        address badHook = address(new MockInvalidHook(address(rewardToken)));

        campaignId =
            _createCampaign({hook: badHook, maxRewardPerVote: 0.1e18, addresses: new address[](0), whitelist: false});

        oracleLens.setTotalVotes(GAUGE, epoch, TOTAL_VOTES);

        /// Skip to the start of the campaign.
        skip(epochLenght);
        epoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, epoch, "");

        Campaign memory campaign = votemarket.getCampaign(campaignId);
        assertEq(campaign.hook, address(badHook));
    }

    function testUpdateEpochWithWhitelistAndZeroVotes() public {
        uint256 epochLenght = votemarket.EPOCH_LENGTH();
        uint256 epoch = votemarket.currentEpoch();
        address[] memory addresses = new address[](10);
        for (uint256 i = 1; i < addresses.length; i++) {
            addresses[i] = address(uint160(i + 1));
        }

        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: MAX_REWARD_PER_VOTE,
            addresses: addresses,
            whitelist: true
        });

        /// Skip to the start of the campaign.
        skip(epochLenght);
        epoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, epoch, "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        Period memory previousPeriod = votemarket.getPeriodPerCampaign(campaignId, epoch - epochLenght);

        /// Since it's the first epoch, there should be no leftover, reward per period should be updated on the go.
        assertEq(previousPeriod.leftover, 0);
        assertEq(previousPeriod.updated, false);
        assertEq(previousPeriod.rewardPerPeriod, 0);
        assertEq(previousPeriod.rewardPerVote, 0);

        uint256 expectedRewardPerPeriod = (TOTAL_REWARD_AMOUNT) / VALID_PERIODS;
        uint256 expectedRewardPerVote = 0;

        if (expectedRewardPerVote > MAX_REWARD_PER_VOTE) {
            expectedRewardPerVote = MAX_REWARD_PER_VOTE;
        }

        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.leftover, period.rewardPerPeriod);
        assertEq(period.rewardPerVote, 0);
        assertEq(period.updated, true);
    }

    function testUpdateEpochWithWhitelist() public {
        uint256 epochLenght = votemarket.EPOCH_LENGTH();
        uint256 epoch = votemarket.currentEpoch();

        address[] memory addresses = new address[](10);
        uint256[] memory accountVotes = new uint256[](10);
        uint256 totalVotes = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            addresses[i] = address(uint160(i + 1));
            accountVotes[i] = i ** 2 + 1e18;
            totalVotes += accountVotes[i];
            oracleLens.setAccountVotes(addresses[i], GAUGE, epoch, accountVotes[i]);
        }

        oracleLens.setTotalVotes(GAUGE, epoch, totalVotes);

        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: MAX_REWARD_PER_VOTE,
            addresses: addresses,
            whitelist: true
        });

        /// Skip to the start of the campaign.
        skip(epochLenght);
        epoch = votemarket.currentEpoch();
        votemarket.updateEpoch(campaignId, epoch, "");

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, epoch);
        Period memory previousPeriod = votemarket.getPeriodPerCampaign(campaignId, epoch - epochLenght);

        /// Since it's the first epoch, there should be no leftover, reward per period should be updated on the go.
        assertEq(previousPeriod.leftover, 0);
        assertEq(previousPeriod.updated, false);
        assertEq(previousPeriod.rewardPerPeriod, 0);
        assertEq(previousPeriod.rewardPerVote, 0);

        uint256 expectedRewardPerPeriod = (TOTAL_REWARD_AMOUNT) / VALID_PERIODS;
        uint256 expectedRewardPerVote = expectedRewardPerPeriod.mulDiv(1e18, totalVotes);

        if (expectedRewardPerVote > MAX_REWARD_PER_VOTE) {
            expectedRewardPerVote = MAX_REWARD_PER_VOTE;
        }

        uint256 expectedLeftOver = expectedRewardPerPeriod - expectedRewardPerVote.mulDiv(totalVotes, 1e18);

        assertEq(period.rewardPerPeriod, expectedRewardPerPeriod);
        assertEq(period.leftover, expectedLeftOver, "Leftover should be updated");
        assertEq(period.rewardPerVote, expectedRewardPerVote);
        assertEq(period.updated, true);
    }
}
