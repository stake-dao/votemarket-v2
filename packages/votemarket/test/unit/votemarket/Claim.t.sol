// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "test/unit/votemarket/Base.t.sol";

contract ClaimTest is BaseTest {
    using FixedPointMathLib for uint256;

    uint256 public campaignId;
    address public recipient = address(0xBEEF);

    function setUp() public override {
        BaseTest.setUp();
        campaignId = _createCampaign();
    }

    function testClaimSuccessful() public {
        skip(1 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        uint256 claimed = votemarket.claim(campaignId, recipient, currentEpoch, "");

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, TOTAL_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);

        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());
        assertApproxEqRel(rewardToken.balanceOf(recipient), expectedClaim, votemarket.fee());
        /// Fee
        assertEq(rewardToken.balanceOf(address(this)), expectedClaim * votemarket.fee() / 1e18);
    }

    function testClaimTwiceInSameEpoch() public {
        skip(1 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        uint256 claimed = votemarket.claim(campaignId, recipient, currentEpoch, "");

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, TOTAL_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);

        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());

        /// We take the fee into account here.
        uint256 claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, currentEpoch, address(this));
        assertEq(claimedPerAccount, expectedClaim);

        claimed = votemarket.claim(campaignId, recipient, currentEpoch, "");
        claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, currentEpoch, address(this));
        assertEq(claimed, 0);
        assertEq(claimedPerAccount, expectedClaim);

        assertApproxEqRel(rewardToken.balanceOf(recipient), expectedClaim, votemarket.fee());
        /// Fee
        assertEq(rewardToken.balanceOf(address(this)), expectedClaim * votemarket.fee() / 1e18);
    }

    function testClaimAccrossMultipleEpochs() public {
        skip(1 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        uint256 claimed = votemarket.claim(campaignId, recipient, currentEpoch, "");

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, TOTAL_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);

        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());

        /// We take the fee into account here.
        uint256 claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, currentEpoch, address(this));
        assertEq(claimedPerAccount, expectedClaim);

        skip(1 weeks);
        currentEpoch = votemarket.currentEpoch();

        uint256 balanceBefore = rewardToken.balanceOf(recipient);
        uint256 feeBefore = rewardToken.balanceOf(address(this));

        claimed = votemarket.claim(campaignId, recipient, currentEpoch, "");
        claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, currentEpoch, address(this));

        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());
        assertEq(claimedPerAccount, expectedClaim);

        assertApproxEqRel(rewardToken.balanceOf(recipient), balanceBefore + expectedClaim, votemarket.fee());
        /// Fee
        assertEq(rewardToken.balanceOf(address(this)), feeBefore + expectedClaim * votemarket.fee() / 1e18);
    }

    function testClaimBeforeCampaignStart() public {
        uint256 currentEpoch = votemarket.currentEpoch();

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, address(this), currentEpoch, "");

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, address(this), currentEpoch, "");
    }

    function testClaimAfterCampaignEnd() public {
        skip(VALID_PERIODS * 1 weeks);

        /// Update previous epoch
        _updateEpochs(campaignId);

        uint256 lastClaimEpoch = votemarket.currentEpoch() - 1 weeks;
        uint256 claimed = votemarket.claim(campaignId, address(this), lastClaimEpoch, "");

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, TOTAL_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);
        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());

        uint256 currentEpoch = votemarket.currentEpoch();
        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, address(this), currentEpoch, "");

        /// We take the fee into account here.
        uint256 claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, lastClaimEpoch, address(this));
        assertEq(claimedPerAccount, expectedClaim);
    }

    function testClaimAfterClaimDeadline() public {
        skip(VALID_PERIODS * 1 weeks);
        skip(votemarket.claimDeadline());

        _updateEpochs(campaignId);

        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 claimed = votemarket.claim(campaignId, address(this), campaign.endTimestamp - 1 weeks, "");
        assertEq(claimed, 0);
    }

    function testReentrancyWithHook() public {
        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker(address(votemarket));
        campaignId = _createCampaign({hook: address(reentrancyAttacker), maxRewardPerVote: 1e16, addresses: blacklist, whitelist: false});

        skip(1 weeks);

        uint currentEpoch = votemarket.currentEpoch();
        bytes memory data = abi.encode(campaignId, currentEpoch);

        vm.expectRevert(ReentrancyGuard.Reentrancy.selector);
        votemarket.claim(campaignId, address(this), currentEpoch, data);
    }

contract ReentrancyAttacker {
    Votemarket public votemarket;

    constructor(address _votemarket) {
        votemarket = Votemarket(_votemarket);
    }

    function doSomething(bytes calldata data) external {
        (uint256 campaignId, uint256 epoch) = abi.decode(data, (uint256, uint256));
        votemarket.claim(campaignId, address(this), epoch, "");
    }

    fallback() external {
        votemarket.claim(0, address(this), 0, "");
    }
}