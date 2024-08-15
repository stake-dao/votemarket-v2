// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";

import "test/mocks/Hooks.sol";
import "test/mocks/OracleLens.sol";

abstract contract BaseTest is Test {
    address creator = address(this);

    MockOracleLens oracleLens;

    MockERC20 rewardToken;
    Votemarket votemarket;

    // Test variables
    address HOOK;
    address[] blacklist;
    uint256 constant CHAIN_ID = 1;
    uint8 constant VALID_PERIODS = 4;
    address constant GAUGE = address(0x1234);
    address constant MANAGER = address(0x5678);
    uint256 constant MAX_REWARD_PER_VOTE = 1e18;
    uint256 constant TOTAL_REWARD_AMOUNT = 1000e18;

    uint256 TOTAL_VOTES = 2000e18;
    uint256 ACCOUNT_VOTES = 1000e18;

    function setUp() public virtual {
        oracleLens = new MockOracleLens();

        votemarket = new Votemarket(address(this), address(this), 1 weeks, 2);
        votemarket.setOracle(address(oracleLens));

        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        HOOK = address(new MockHook(address(rewardToken)));

        /// To avoid timestamp = 0.
        skip(1 weeks);
    }

    function _createCampaign() internal returns (uint256 campaignId) {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        campaignId = votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            creator,
            address(rewardToken),
            VALID_PERIODS,
            MAX_REWARD_PER_VOTE,
            TOTAL_REWARD_AMOUNT,
            blacklist,
            HOOK,
            false
        );

        _mockGaugeData(campaignId, GAUGE);
        _mockAccountData(campaignId, address(this), GAUGE);
    }

    function _createCampaign(address hook, uint256 maxRewardPerVote, address[] memory addresses, bool whitelist)
        internal
        returns (uint256 campaignId)
    {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        campaignId = votemarket.createCampaign(
            CHAIN_ID,
            GAUGE,
            creator,
            address(rewardToken),
            VALID_PERIODS,
            maxRewardPerVote,
            TOTAL_REWARD_AMOUNT,
            addresses,
            hook,
            whitelist
        );

        _mockGaugeData(campaignId, GAUGE);
        _mockAccountData(campaignId, address(this), GAUGE);
    }

    function testSetters() public {
        /// Fee collector.
        address feeCollector = address(0xCAFE);
        votemarket.setFeeCollector(feeCollector);

        assertEq(votemarket.feeCollector(), feeCollector);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setFeeCollector(feeCollector);

        vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        votemarket.setFeeCollector(address(0));

        /// Fee.
        uint256 fee = 100;
        votemarket.setFee(fee);
        assertEq(votemarket.fee(), fee);

        vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        votemarket.setFee(1e18);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setFee(fee);

        vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        votemarket.setFee(1e18);

        /// Fee collector.
        address remote = address(0xCAFE);
        votemarket.setRemote(feeCollector);
        assertEq(votemarket.remote(), remote);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setRemote(remote);
    }

    function testGetters() public {
        _createCampaign();
        uint256 campaignId = votemarket.campaignCount() - 1;

        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 4);
        skip(4 weeks);
        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 0);
    }

    function _updateEpochs(uint256 campaignId) internal {
        /// Get the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 endTimestamp = campaign.endTimestamp;
        uint256 startTimestamp = campaign.startTimestamp;

        for (uint256 i = startTimestamp; i < endTimestamp; i += 1 weeks) {
            votemarket.updateEpoch(campaignId, i, "");

            /// Get the campaign.
            campaign = votemarket.getCampaign(campaignId);
            endTimestamp = campaign.endTimestamp;
        }
    }

    function _mockGaugeData(uint256 campaignId, address gauge) internal {
        /// Get the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 endTimestamp = campaign.endTimestamp;
        uint256 startTimestamp = campaign.startTimestamp - 1 weeks;

        for (uint256 i = startTimestamp; i < endTimestamp; i += 1 weeks) {
            oracleLens.setTotalVotes(gauge, i, TOTAL_VOTES);
        }
    }

    function _mockAccountData(uint256 campaignId, address account, address gauge) internal {
        /// Get the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 endTimestamp = campaign.endTimestamp;
        uint256 startTimestamp = campaign.startTimestamp - 1 weeks;

        for (uint256 i = startTimestamp; i < endTimestamp; i += 1 weeks) {
            oracleLens.setAccountVotes(account, gauge, i, ACCOUNT_VOTES);
        }
    }
}
