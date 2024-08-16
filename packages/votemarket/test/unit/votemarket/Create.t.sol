// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// Testing contracts & libraries
import "test/unit/votemarket/Base.t.sol";

contract CreateCampaignTest is BaseTest {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    function setUp() public override {
        BaseTest.setUp();
    }

    function testCreateCampaign() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        uint256 campaignId = votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );

        assertEq(votemarket.campaignCount(), campaignId + 1);

        (
            uint256 chainId,
            address gauge,
            address manager,
            address campaignRewardToken,
            uint8 numberOfPeriods,
            uint256 maxRewardPerVote,
            uint256 totalRewardAmount,
            uint256 startTimestamp,
            uint256 endTimestamp
        ) = votemarket.campaignById(campaignId);

        assertEq(chainId, CHAIN_ID);
        assertEq(gauge, GAUGE);
        assertEq(manager, MANAGER);
        assertEq(campaignRewardToken, address(rewardToken));
        assertEq(numberOfPeriods, VALID_PERIODS);
        assertEq(maxRewardPerVote, MAX_REWARD_PER_VOTE);
        assertEq(totalRewardAmount, TOTAL_REWARD_AMOUNT);

        assertEq(startTimestamp, votemarket.currentEpoch() + 1 weeks);
        assertEq(endTimestamp, startTimestamp + VALID_PERIODS * 1 weeks);

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, startTimestamp);
        assertEq(period.rewardPerPeriod, TOTAL_REWARD_AMOUNT / VALID_PERIODS);
        _checkHookAndAddresses(campaignId, HOOK, blacklist, startTimestamp, endTimestamp);

    }

    function testCreateCampaignWithInvalidPeriods() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        uint8 invalidPeriods = votemarket.MINIMUM_PERIODS() - 1;

        vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            invalidPeriods,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithZeroRewardAmount() public {
        vm.expectRevert(Votemarket.ZERO_INPUT.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            0,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithZeroMaxRewardPerVote() public {
        vm.expectRevert(Votemarket.ZERO_INPUT.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            0,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithZeroGauge() public {
        vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            address(0),
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithZeroRewardToken() public {
        vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(0),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithInvalidRewardToken() public {
        address invalidToken = address(0x1111);
        vm.expectRevert(Votemarket.INVALID_TOKEN.selector);
        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            invalidToken,
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );
    }

    function testCreateCampaignWithBlacklist() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address[] memory testBlacklist = new address[](2);
        testBlacklist[0] = address(0xDEAD);
        testBlacklist[1] = address(0xBEEF);

        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            testBlacklist,
            HOOK,
            false
        );

        uint256 campaignId = votemarket.campaignCount() - 1;

        address[] memory blacklistArray = votemarket.getAddressesByCampaign(campaignId, votemarket.currentEpoch() + 1 weeks);

        assertFalse(votemarket.whitelistOnly(campaignId));
        assertEq(blacklistArray.length, 2);
        assertEq(blacklistArray[0], address(0xDEAD));
        assertEq(blacklistArray[1], address(0xBEEF));
    }

    function testCreateCampaignWithIdenticalBlacklist() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address[] memory testBlacklist = new address[](2);
        testBlacklist[0] = address(0xDEAD);
        testBlacklist[1] = address(0xDEAD);

        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            testBlacklist,
            HOOK,
            false
        );

        uint256 campaignId = votemarket.campaignCount() - 1;

        address[] memory blacklistArray = votemarket.getAddressesByCampaign(campaignId, votemarket.currentEpoch() + 1 weeks);

        assertFalse(votemarket.whitelistOnly(campaignId));
        assertEq(blacklistArray.length, 1);
        assertEq(blacklistArray[0], address(0xDEAD));
    }

    function testCreateCampaignWithWhitelist() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address[] memory testWhitelist = new address[](2);
        testWhitelist[0] = address(0xDEAD);
        testWhitelist[1] = address(0xBEEF);

        uint256 campaignId = votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            testWhitelist,
            HOOK,
            true
        );

        address[] memory campaignBlacklist = votemarket.getAddressesByCampaign(campaignId, votemarket.currentEpoch() + 1 weeks);

        assertTrue(votemarket.whitelistOnly(campaignId));
        assertEq(campaignBlacklist.length, 2);
        assertEq(campaignBlacklist[0], address(0xDEAD));
        assertEq(campaignBlacklist[1], address(0xBEEF));
    }

    function testCreateCampaignWithoutHook() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        uint256 campaignId = votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            address(0),
            false
        );

        Period memory period = votemarket.getPeriodPerCampaign(campaignId, votemarket.currentEpoch() + 1 weeks);
        assertEq(period.hook, address(0));
    }

    function testCreateCampaignWithHook() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address mockHook = address(new MockHook(address(rewardToken)));

        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            mockHook,
            false
        );

        uint256 campaignId = votemarket.campaignCount() - 1;
        Period memory period = votemarket.getPeriodPerCampaign(campaignId, votemarket.currentEpoch() + 1 weeks);
        assertEq(period.hook, mockHook);
    }

    function testCurrentPeriod() public view {
        uint256 expectedPeriod = block.timestamp / 1 weeks * 1 weeks;
        assertEq(votemarket.currentEpoch(), expectedPeriod);
    }
}
