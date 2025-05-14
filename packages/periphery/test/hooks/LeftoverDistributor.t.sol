// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import {IVotemarket, Campaign} from "@votemarket/src/interfaces/IVotemarket.sol";
import {FakeToken} from "../mocks/FakeToken.sol";
import {LeftoverDistributorHook} from "../../src/hooks/LeftoverDistributorHook.sol";

contract LeftoverDistributorTest is Test {
    FakeToken rewardToken;
    IVotemarket votemarket = IVotemarket(0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9);
    LeftoverDistributorHook hook;
    uint256 campaignId;
    uint256 expectedLeftOver = 499992810414009245950;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.createSelectFork("arbitrum", 331532381);

        // create a campaign in the past
        rewind(7 days);

        rewardToken = new FakeToken("Mock Token", "MOCK", 18);
        rewardToken.mint(address(this), 1000e18);

        hook = new LeftoverDistributorHook(address(this));

        rewardToken.approve(address(votemarket), 1000e18);
        // sdCRV gauge, which has votes
        // set a really little max price per vote, 1 gwei, to ensure leftover
        address[] memory addresses = new address[](0);
        campaignId = votemarket.createCampaign(
            1,
            address(0x26F7786de3E6D9Bd37Fcf47BE6F2bC455a21b74A),
            alice,
            address(rewardToken),
            2,
            1 gwei,
            1000e18,
            addresses,
            address(hook),
            false
        );

        // back to current timestamp
        skip(7 days);
    }

    function test_initialState() public view {
        assertGt(campaignId, 0);
        Campaign memory campaign = votemarket.getCampaign(campaignId);
        assertEq(campaign.rewardToken, address(rewardToken));
        assertEq(campaign.maxRewardPerVote, 1 gwei);
        assertEq(campaign.hook, address(hook));
        assertEq(campaign.manager, alice);
    }

    // Test errors on a votemarket platform not set
    function test_unsetVotemarketExpectedErrors() public {
        // calling doSomething if not whitelisted in the hook
        vm.expectRevert(LeftoverDistributorHook.UNAUTHORIZED_VOTEMARKET.selector);
        hook.doSomething(campaignId, 0, address(rewardToken), 0, 1 gwei, bytes("0x"));

        // calling setRecipient on a not set votemarket
        vm.expectRevert(LeftoverDistributorHook.UNAUTHORIZED_VOTEMARKET.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId, alice);
    }

    /// Tests to enable / disable votemarket addresses
    function test_toggleVotemarket() public {
        // Expect to revert if not owner
        vm.prank(alice);
        vm.expectRevert();
        hook.enableVotemarket(address(votemarket));

        // Expect to be false by default
        assertEq(hook.votemarkets(address(votemarket)), false);
        hook.enableVotemarket(address(votemarket));
        assertEq(hook.votemarkets(address(votemarket)), true);

        // Expect to revert if not owner
        vm.prank(alice);
        vm.expectRevert();
        hook.disableVotemarket(address(votemarket));

        // Expect to unset
        hook.disableVotemarket(address(votemarket));
        assertEq(hook.votemarkets(address(votemarket)), false);
    }

    /// Tests for recipient settings
    function test_setLeftoverRecipient() public {
        hook.enableVotemarket(address(votemarket));

        // Not anyone can set the recipient
        vm.expectRevert(LeftoverDistributorHook.UNAUTHORIZED.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId, address(this));

        // Alice is the manager, can set the recipient
        vm.prank(alice);
        hook.setLeftOverRecipient(address(votemarket), campaignId, address(this));
        assertEq(hook.leftoverRecipients(address(votemarket), campaignId), address(this));

        // New recipient can set an other recipient
        hook.setLeftOverRecipient(address(votemarket), campaignId, bob);
        assertEq(hook.leftoverRecipients(address(votemarket), campaignId), bob);

        // Old recipient can't set an other recipient
        vm.expectRevert(LeftoverDistributorHook.UNAUTHORIZED.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId, address(this));

        // Can't set recipient for not existing campaign
        vm.expectRevert(LeftoverDistributorHook.UNAUTHORIZED.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId + 1, address(this));
    }

    /// Tests for recipient overrides
    function test_overrideLeftoverRecipient() public {
        hook.enableVotemarket(address(votemarket));

        // Not governance can't override the recipient
        vm.expectRevert();
        vm.prank(alice);
        hook.overrideLeftOverRecipient(address(votemarket), campaignId, address(this));

        // The governance can set the recipient
        hook.overrideLeftOverRecipient(address(votemarket), campaignId, address(this));
        assertEq(hook.leftoverRecipients(address(votemarket), campaignId), address(this));
    }

    /// Test default flow, leftover is sent to the manager
    function test_defaultFlowWithVotemarket() public {
        hook.enableVotemarket(address(votemarket));

        votemarket.updateEpoch(campaignId, block.timestamp / 1 weeks * 1 weeks, bytes("0x"));

        assertEq(rewardToken.balanceOf(alice), expectedLeftOver);
        assertEq(rewardToken.balanceOf(address(hook)), 0);
    }

    /// Test if recipient set does send the leftover to the right address
    function test_recipientFlowWithVotemarket() public {
        hook.enableVotemarket(address(votemarket));

        vm.prank(alice);
        hook.setLeftOverRecipient(address(votemarket), campaignId, bob);
        assertEq(hook.leftoverRecipients(address(votemarket), campaignId), bob);

        votemarket.updateEpoch(campaignId, block.timestamp / 1 weeks * 1 weeks, bytes("0x"));

        assertEq(rewardToken.balanceOf(alice), 0);
        assertEq(rewardToken.balanceOf(bob), expectedLeftOver);
        assertEq(rewardToken.balanceOf(address(hook)), 0);
    }

    /// Test if the changing the manager also changes the default recipient
    function test_defaultFlowChangingManagerOnVotemarket() public {
        hook.enableVotemarket(address(votemarket));

        vm.prank(alice);
        votemarket.updateManager(campaignId, bob);

        votemarket.updateEpoch(campaignId, block.timestamp / 1 weeks * 1 weeks, bytes("0x"));

        assertEq(rewardToken.balanceOf(alice), 0);
        assertEq(rewardToken.balanceOf(bob), expectedLeftOver);
        assertEq(rewardToken.balanceOf(address(hook)), 0);
    }

    /// /!\ /!\ /!\  TO AVOID  /!\ /!\ /!\
    /// Flow in case a votemarket platform is not correctly toggled in the contract
    function test_unsetVotemarketIssue() public {
        // We don't enable the platform on purpose to revert the doSomething call

        votemarket.updateEpoch(campaignId, block.timestamp / 1 weeks * 1 weeks, bytes("0x"));

        // Votemarket doesn't check the execution success on the hook, so it just transfered the tokens to the hook and the hook reverted
        assertEq(rewardToken.balanceOf(alice), 0);
        assertEq(rewardToken.balanceOf(address(hook)), expectedLeftOver);

        // We don't want anyone to be able to rescue the ERC20, even the manager
        vm.prank(alice);
        vm.expectRevert();
        hook.rescueERC20(address(rewardToken), expectedLeftOver, alice);

        // Owner can call rescueERC20 and send it to the manager
        hook.rescueERC20(address(rewardToken), expectedLeftOver, alice);

        assertEq(rewardToken.balanceOf(alice), expectedLeftOver);
        assertEq(rewardToken.balanceOf(address(hook)), 0);
    }
}
