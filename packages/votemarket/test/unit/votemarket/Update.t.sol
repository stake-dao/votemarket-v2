// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract UpdateEpochTest is BaseTest {
    uint256 public campaignId;

    function setUp() public override {
        BaseTest.setUp();

        campaignId = _createCampaign();

        uint256 currentEpoch = votemarket.currentEpoch();

        // Initialize the oracle with some votes
        MockOracleLens mockOracle = new MockOracleLens();

        mockOracle.setTotalVotes(GAUGE, currentEpoch, 10_000e18);
        votemarket.setOracle(address(mockOracle));
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

    function testUpdateEpoch() public {}
    function testUpdateEpochForSubsequentPeriods() public {}
    function testAlreadyUpdatedEpoch() public {}

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
