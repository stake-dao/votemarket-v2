// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/src/Test.sol";
import "forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";
import "test/mocks/Hooks.sol";

contract VotemarketUnitTest is Test {
    address creator = address(this);
    MockERC20 rewardToken;
    Votemarket votemarket;

    // Test variables
    address HOOK;
    address[] blacklist;
    uint256 constant CHAIN_ID = 1;
    uint8 constant VALID_PERIODS = 4;
    address constant GAUGE = address(0x1234);
    address constant MANAGER = address(0x5678);
    uint256 constant MAX_REWARD_PER_VOTE = 100e18;
    uint256 constant TOTAL_REWARD_AMOUNT = 1000e18;

    function setUp() public {
        votemarket = new Votemarket();
        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        HOOK = address(new MockHook());
    }

    function testCreateCampaign() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        uint256 initialCampaignCount = votemarket.campaignCount();

        votemarket.createCampaign(
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

        assertEq(votemarket.campaignCount(), initialCampaignCount + 1);

        (
            uint256 chainId,
            address gauge,
            address manager,
            address campaignRewardToken,
            uint8 numberOfPeriods,
            uint256 maxRewardPerVote,
            uint256 totalRewardAmount,
            uint256 endTimestamp
        ) = votemarket.campaignById(initialCampaignCount);

        assertEq(chainId, CHAIN_ID);
        assertEq(gauge, GAUGE);
        assertEq(manager, MANAGER);
        assertEq(campaignRewardToken, address(rewardToken));
        assertEq(numberOfPeriods, VALID_PERIODS);
        assertEq(maxRewardPerVote, MAX_REWARD_PER_VOTE);
        assertEq(totalRewardAmount, TOTAL_REWARD_AMOUNT);
        assertEq(endTimestamp, (block.timestamp / 1 weeks * 1 weeks) + VALID_PERIODS * 1 weeks);
    }

    function testCreateCampaignWithInvalidPeriods() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        uint8 invalidPeriods = votemarket.MINIMUM_PERIODS() - 1;


        vm.expectRevert(Votemarket.INVALID_NUMBER_OF_PERIODS.selector);
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
        assertTrue(votemarket.isBlacklisted(campaignId, address(0xDEAD)));
        assertTrue(votemarket.isBlacklisted(campaignId, address(0xBEEF)));
        assertFalse(votemarket.isBlacklisted(campaignId, address(0x1234)));
    }

    function testCreateCampaignWithWhitelist() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address[] memory testWhitelist = new address[](2);
        testWhitelist[0] = address(0xDEAD);
        testWhitelist[1] = address(0xBEEF);

        votemarket.createCampaign(
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

        uint256 campaignId = votemarket.campaignCount() - 1;
        assertTrue(votemarket.isWhitelisted(campaignId, address(0xDEAD)));
        assertTrue(votemarket.isWhitelisted(campaignId, address(0xBEEF)));
        assertFalse(votemarket.isWhitelisted(campaignId, address(0x1234)));
    }

    function testCreateCampaignWithHook() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address mockHook = address(new MockHook());

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
        assertEq(votemarket.hookByCampaignId(campaignId), mockHook);
    }

    function testCreateCampaignWithInvalidHook() public {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        address invalidHook = address(new MockInvalidHook());

        votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            MANAGER,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            invalidHook,
            false
        );

        uint256 campaignId = votemarket.campaignCount() - 1;
        assertEq(votemarket.hookByCampaignId(campaignId), address(0));
    }

    function testCurrentPeriod() view public {
        uint256 expectedPeriod = block.timestamp / 1 weeks * 1 weeks;
        assertEq(votemarket.currentPeriod(), expectedPeriod);
    }
}