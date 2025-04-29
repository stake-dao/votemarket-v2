// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import {IVotemarket, Campaign} from "@votemarket/src/interfaces/IVotemarket.sol";
import {FakeToken} from "../mocks/FakeToken.sol";
import {NoRolloverHook} from "../../src/hooks/NoRolloverHook.sol";

contract NoRolloverHookTest is Test {

    FakeToken rewardToken;
    IVotemarket votemarket = IVotemarket(0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9);
    NoRolloverHook hook;
    uint256 campaignId;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        vm.createSelectFork("arbitrum", 331532381);

        // create a campaign in the past
        rewind(7 days);

        rewardToken = new FakeToken("Mock Token", "MOCK", 18);
        rewardToken.mint(address(this), 1000e18);

        hook = new NoRolloverHook(address(this));

        rewardToken.approve(address(votemarket), 1000e18);
        // sdCRV gauge, which has votes
        // set a really little max price per vote, 1 gwei, to ensure leftover
        address[] memory addresses = new address[](0);
        campaignId = votemarket.createCampaign(1, address(0x26F7786de3E6D9Bd37Fcf47BE6F2bC455a21b74A), alice, address(rewardToken), 2, 1 gwei, 1000e18, addresses, address(hook), false);

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

    function test_unsetVotemarketExpectedErrors() public {
        // calling doSomething if not whitelisted in the hook
        vm.expectRevert(NoRolloverHook.UNAUTHORIZED_VOTEMARKET.selector);
        hook.doSomething(campaignId, 0, address(rewardToken), 0, 1 gwei, bytes("0x"));

        // calling setRecipient on a not set votemarket
        vm.expectRevert(NoRolloverHook.UNAUTHORIZED_VOTEMARKET.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId, alice);
    }

    function test_toggleVotemarket() public {
        // Expect to revert if not owner
        vm.prank(alice);
        vm.expectRevert();
        hook.toggleVotemarket(address(votemarket));

        // Expect to be false by default
        assertEq(hook.votemarkets(address(votemarket)), false);
        hook.toggleVotemarket(address(votemarket));
        assertEq(hook.votemarkets(address(votemarket)), true);

        // Expect to unset already set
        hook.toggleVotemarket(address(votemarket));
        assertEq(hook.votemarkets(address(votemarket)), false);
    }

    function test_setLeftoverRecipient() public {
        hook.toggleVotemarket(address(votemarket));

        // Not anyone can set the recipient
        vm.expectRevert(NoRolloverHook.UNAUTHORIZED.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId, address(this));

        // Alice is the manager, can set the recipient
        vm.prank(alice);
        hook.setLeftOverRecipient(address(votemarket), campaignId, address(this));
        assertEq(hook.leftOverRecipients(address(votemarket),campaignId), address(this));

        // New recipient can set an other recipient
        hook.setLeftOverRecipient(address(votemarket), campaignId, bob);
        assertEq(hook.leftOverRecipients(address(votemarket),campaignId), bob);

        // Can't set recipient for not existing campaign
        vm.expectRevert(NoRolloverHook.UNAUTHORIZED.selector);
        hook.setLeftOverRecipient(address(votemarket), campaignId +1, address(this));
    }
}