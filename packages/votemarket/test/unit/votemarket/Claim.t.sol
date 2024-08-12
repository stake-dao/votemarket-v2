// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract ClaimTest is BaseTest {
    using FixedPointMathLib for uint256;

    uint256 public campaignId;

    function setUp() public override {
        BaseTest.setUp();

        campaignId = _createCampaign();
    }

    function testClaimCampaignNotStarted() public {
        uint256 currentEpoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.CAMPAIGN_NOT_STARTED.selector);
        votemarket.claim(campaignId, address(this), currentEpoch, "");
    }
}
