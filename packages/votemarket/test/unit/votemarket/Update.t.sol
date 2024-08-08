// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract UpdateEpochTest is BaseTest {
    uint256 public campaignId;
    uint256 public initialEpoch;

    function setUp() public override {
        BaseTest.setUp();

        // Create a campaign
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        vm.startPrank(creator);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);
        campaignId = votemarket.createCampaign(
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
        vm.stopPrank();

        initialEpoch = votemarket.currentEpoch();

        // Initialize the oracle with some votes
        MockOracleLens mockOracle = new MockOracleLens();
        mockOracle.setTotalVotes(GAUGE, initialEpoch, 1000 * 1e18);
        votemarket.setOracle(address(mockOracle));

        // Initialize the first period
        votemarket.updateEpoch(campaignId, initialEpoch);

        // Skip to the next epoch
        skip(1 weeks);
        initialEpoch = votemarket.currentEpoch();
    }
}
