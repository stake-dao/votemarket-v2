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

        uint256 claimed = votemarket.claim(campaignId, currentEpoch, "", recipient);

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

        uint256 claimed = votemarket.claim(campaignId, currentEpoch, "", recipient);

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, TOTAL_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);

        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());

        /// We take the fee into account here.
        uint256 claimedPerAccount = votemarket.totalClaimedByAccount(campaignId, currentEpoch, address(this));
        assertEq(claimedPerAccount, expectedClaim);

        claimed = votemarket.claim(campaignId, currentEpoch, "", recipient);
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

        uint256 claimed = votemarket.claim(campaignId, currentEpoch, "", recipient);

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

        claimed = votemarket.claim(campaignId, currentEpoch, "", recipient);
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
        votemarket.claim(campaignId, currentEpoch, "", address(this));

        vm.expectRevert(Votemarket.EPOCH_NOT_VALID.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));
    }

    function testClaimAfterCampaignEnd() public {
        skip(5 * 1 weeks);

        /// Update previous epoch
        _updateEpochs(campaignId);

        uint256 lastClaimEpoch = votemarket.currentEpoch() - 1 weeks;
        uint256 claimed = votemarket.claim(campaignId, lastClaimEpoch, "", address(this));

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
        skip(5 * 1 weeks);
        skip(votemarket.CLAIM_WINDOW_LENGTH());

        _updateEpochs(campaignId);

        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 claimed = votemarket.claim(campaignId, campaign.endTimestamp - 1 weeks, "", address(this));
        assertEq(claimed, 0);
    }

    function testClaimWithWhitelistOnlyCampaign() public {
        blacklist = new address[](1);
        blacklist[0] = address(this);

        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: MAX_REWARD_PER_VOTE,
            addresses: blacklist,
            whitelist: true
        });

        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_WHITELIST_ONLY.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));

        uint256 expectedRewardPerVote = (TOTAL_REWARD_AMOUNT / 4).mulDiv(1e18, ACCOUNT_VOTES);
        uint256 expectedClaim = ACCOUNT_VOTES.mulDiv(expectedRewardPerVote, 1e18);
        uint256 claimed = votemarket.claim(campaignId, currentEpoch, "", address(this));

        /// Since the recipient and the fee collector are the same, it should be the same as the expected claim.
        assertApproxEqRel(claimed, expectedClaim, votemarket.fee());
        assertEq(rewardToken.balanceOf(address(this)), expectedClaim);
    }

    function testClaimExceedingRewardAmount() public {
        skip(1 weeks);

        ACCOUNT_VOTES = 400e18;
        address[] memory addresses = new address[](10);
        /// Let's say the oracle is vulnerable and returns 100 votes for an account.
        for (uint256 i = 0; i < 9; i++) {
            addresses[i] = address(uint160(i + 1));
            oracleLens.setAccountVotes(addresses[i], GAUGE, votemarket.currentEpoch(), ACCOUNT_VOTES);
        }
        addresses[9] = address(this);

        address random = address(0xBEEF);
        oracleLens.setAccountVotes(random, GAUGE, votemarket.currentEpoch(), ACCOUNT_VOTES);

        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: MAX_REWARD_PER_VOTE,
            addresses: new address[](0),
            whitelist: false
        });

        oracleLens.setTotalVotes(GAUGE, votemarket.currentEpoch(), TOTAL_REWARD_AMOUNT);

        deal(address(rewardToken), address(this), TOTAL_REWARD_AMOUNT * 3);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT * 3);
        votemarket.increaseTotalRewardAmount(campaignId, TOTAL_REWARD_AMOUNT * 3);

        skip(1 weeks);
        uint256 currentEpoch = votemarket.currentEpoch();

        for (uint256 i = 0; i < 10; i++) {
            vm.prank(addresses[i]);
            votemarket.claim(campaignId, currentEpoch, "", address(this));
        }

        vm.prank(random);
        vm.expectRevert(Votemarket.CLAIM_AMOUNT_EXCEEDS_REWARD_AMOUNT.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));
    }

    function testClaimBlacklistOnlyCampaign() public {
        blacklist = new address[](1);
        blacklist[0] = address(this);

        campaignId = _createCampaign({
            hook: address(0),
            maxRewardPerVote: MAX_REWARD_PER_VOTE,
            addresses: blacklist,
            whitelist: false
        });

        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();

        vm.prank(address(this));
        vm.expectRevert(Votemarket.AUTH_BLACKLISTED.selector);
        votemarket.claim(campaignId, currentEpoch, "", address(this));
    }

    function testReentrancyWithHook() public {
        ReentrancyAttacker reentrancyAttacker = new ReentrancyAttacker(address(votemarket));
        campaignId = _createCampaign({
            hook: address(reentrancyAttacker),
            maxRewardPerVote: 1e16,
            addresses: blacklist,
            whitelist: false
        });

        skip(1 weeks);

        uint256 currentEpoch = votemarket.currentEpoch();
        bytes memory data = abi.encode(campaignId, currentEpoch);

        Campaign memory campaign = votemarket.getCampaign(campaignId);
        assertEq(campaign.hook, address(reentrancyAttacker));
        votemarket.claim(campaignId, currentEpoch, data, address(this));
    }
}

contract ReentrancyAttacker {
    Votemarket public votemarket;

    constructor(address _votemarket) {
        votemarket = Votemarket(_votemarket);
    }

    function doSomething(bytes calldata data) external {
        (uint256 campaignId, uint256 epoch) = abi.decode(data, (uint256, uint256));
        votemarket.claim(campaignId, epoch, "", address(this));
    }

    function returnFunds(address token, address to, uint256 amount) external {
        SafeTransferLib.safeTransfer(token, to, amount);
    }

    fallback() external {
        votemarket.claim(0, 0, "", address(this));
    }
}
