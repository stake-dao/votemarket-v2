// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import "forge-std/src/Test.sol";
import "../../src/helpers/YBHelper.sol";
import {FakeToken} from "../mocks/FakeToken.sol";

contract DepositHelperSettersTest is Test {
    DepositHelper helper;

    address owner = makeAddr("owner");
    address manager = makeAddr("manager");
    address rewardNotifier = makeAddr("notifier");
    address campaignRemoteManager = 0x53aD4Cd1F1e52DD02aa9FC4A8250A1b74F351CA2;
    address votemarket = 0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9;
    address rewardToken;
    address other = makeAddr("other");
    address gauge = makeAddr("gauge");

    function setUp() public {
        vm.createSelectFork("mainnet");

        vm.startPrank(manager);
        rewardToken = address(new FakeToken("Mock Token", "MOCK", 18));
        helper = new DepositHelper(
            rewardToken,
            rewardNotifier,
            owner,
            campaignRemoteManager,
            votemarket,
            1e18 // maxRewardPerVote
        );
        vm.stopPrank();
    }

    // --- Owner functions ---

    function testSetManager() public {
        vm.startPrank(owner);
        helper.setManager(address(0x123));
        assertEq(helper.manager(), address(0x123));
        vm.stopPrank();
    }

    function testSetManagerRevertsIfNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.UNAUTHORIZED.selector));
        helper.setManager(address(0x123));
    }

    function testSetRewardToken() public {
        address newToken = address(new FakeToken("Mock Token 2", "MOCK2", 18));
        vm.startPrank(owner);
        helper.setRewardToken(newToken);
        assertEq(helper.rewardToken(), newToken);
        vm.stopPrank();
    }

    function testSetRewardNotifier() public {
        address newNotifier = makeAddr("newNotifier");
        vm.startPrank(owner);
        helper.setRewardNotifier(newNotifier);
        assertEq(helper.rewardNotifier(), newNotifier);
        vm.stopPrank();
    }

    function testSetCampaignRemoteManager() public {
        address newCRM = makeAddr("newCRM");
        vm.startPrank(owner);
        helper.setCampaignRemoteManager(newCRM);
        assertEq(helper.campaignRemoteManager(), newCRM);
        vm.stopPrank();
    }

    function testSetVotemarket() public {
        address newVM = makeAddr("newVotemarket");
        vm.startPrank(owner);
        helper.setVotemarket(newVM);
        assertEq(helper.votemarket(), newVM);
        vm.stopPrank();
    }

    function testAddAndRemoveApprovedGauge() public {
        vm.startPrank(owner);
        helper.addApprovedGauge(gauge);
        assertTrue(helper.isApprovedGauge(gauge));
        helper.removeApprovedGauge(gauge);
        assertFalse(helper.isApprovedGauge(gauge));
        vm.stopPrank();
    }

    function testRemoveGaugeRevertsIfHasWeight() public {
        vm.startPrank(owner);
        helper.addApprovedGauge(gauge);
        address[] memory gauges = new address[](1);
        uint16[] memory weights = new uint16[](1);
        gauges[0] = gauge;
        weights[0] = 10000;

        // owner is also manager by _onlyManager() condition
        helper.setWeights(gauges, weights);

        vm.expectRevert(abi.encodeWithSelector(DepositHelper.HAS_WEIGHT.selector));
        helper.removeApprovedGauge(gauge);
        vm.stopPrank();
    }

    function testWithdrawEther() public {
        vm.deal(address(helper), 1 ether);
        vm.startPrank(owner);
        uint256 before = owner.balance;
        helper.withdrawEther(1 ether, payable(owner));
        assertEq(owner.balance, before + 1 ether);
        vm.stopPrank();
    }

    function testWithdrawEtherRevertsIfInvalid() public {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.INVALID_PARAMETER.selector));
        helper.withdrawEther(0, payable(owner));
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.INVALID_PARAMETER.selector));
        helper.withdrawEther(1 ether, payable(address(0)));
        vm.stopPrank();
    }

    // --- Manager functions ---

    function testSetMaxRewardPerVote() public {
        vm.startPrank(manager);
        helper.setMaxRewardPerVote(42);
        assertEq(helper.maxRewardPerVote(), 42);
        vm.stopPrank();
    }

    function testSetHook() public {
        vm.startPrank(manager);
        address hook = makeAddr("hook");
        helper.setHook(hook);
        assertEq(helper.hook(), hook);
        vm.stopPrank();
    }

    function testSetGasSettings() public {
        vm.startPrank(manager);
        helper.setGasSettings(100, 200, 300);
        (uint256 gas1, uint256 gas2, uint256 gas3) = helper.gasSettings();
        assertEq(gas1, 100);
        assertEq(gas2, 200);
        assertEq(gas3, 300);
        vm.stopPrank();
    }

    function testSetGasSettingsRevertsOnZero() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.INVALID_PARAMETER.selector));
        helper.setGasSettings(0, 100, 100);
        vm.stopPrank();
    }

    function testSetExcludeAddressesWrongOrder() public {
        address[] memory excluded = new address[](2) ;
        excluded[0] = makeAddr("a");
        excluded[1] = makeAddr("b");

        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.NOT_SORTED_ADDRESSES.selector));
        helper.setExcludeAddresses(excluded);
        vm.stopPrank();
    }

    function testSetExcludeAddresses() public {
        address[] memory excluded = new address[](2) ;
        excluded[0] = makeAddr("b");
        excluded[1] = makeAddr("a");

        vm.startPrank(manager);
        helper.setExcludeAddresses(excluded);
        vm.stopPrank();
        assertEq(helper.excludeAddresses(0), excluded[0]);
        assertEq(helper.excludeAddresses(1), excluded[1]);

        vm.expectRevert();
        helper.excludeAddresses(2);
    }

    function testSetWeightsWrongOrder() public {
        vm.startPrank(owner);
        helper.addApprovedGauge(makeAddr("a"));
        helper.addApprovedGauge(makeAddr("b"));
        vm.stopPrank();

        address[] memory gauges = new address[](2);
        uint16[] memory weights = new uint16[](2);
        gauges[0] = makeAddr("a");
        gauges[1] = makeAddr("b");
        weights[0] = 3000;
        weights[1] = 7000;

        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.NOT_SORTED_ADDRESSES.selector));
        helper.setWeights(gauges, weights);
        vm.stopPrank();

    }

    function testSetWeights() public {
        vm.startPrank(owner);
        helper.addApprovedGauge(gauge);
        vm.stopPrank();

        address[] memory gauges = new address[](1);
        uint16[] memory weights = new uint16[](1);
        gauges[0] = gauge;
        weights[0] = 10000;

        vm.startPrank(manager);
        helper.setWeights(gauges, weights);
        (address[] memory currentGauges, uint16[] memory currentWeights) = helper.getCurrentWeights();
        assertEq(currentGauges[0], gauge);
        assertEq(currentWeights[0], 10000);
        vm.stopPrank();

        assertEq(helper.currentWeightOfGauge(gauge), 10000);
    }

    function testSetWeightsRevertsIfNotApproved() public {
        
        address[] memory gauges = new address[](1);
        uint16[] memory weights = new uint16[](1);
        gauges[0] = gauge;
        weights[0] = 10000;

        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(DepositHelper.NOT_APPROVED_GAUGE.selector));
        helper.setWeights(gauges, weights);
        vm.stopPrank();
    }

    // --- Main function ---

    function testNotifyReward() public {
        // fund helper with ETH for gas
        vm.deal(address(helper), 10 ether);

        // Approve some gauges
        vm.startPrank(owner);
        helper.addApprovedGauge(makeAddr("gauge1"));
        helper.addApprovedGauge(makeAddr("gauge2"));
        vm.stopPrank();

        // Set weights
        address[] memory gauges = new address[](2) ;
        gauges[0] = makeAddr("gauge1");
        gauges[1] = makeAddr("gauge2");
        uint16[] memory weights = new uint16[](2) ;
        weights[0] = 6000;
        weights[1] = 4000;
        vm.startPrank(manager);
        helper.setWeights(gauges, weights);
        vm.stopPrank();

        // Deal reward tokens to notifier
        FakeToken(rewardToken).mint(rewardNotifier, 1000 ether);

        uint256 amount = 100 ether;

        vm.startPrank(rewardNotifier);
        IERC20(rewardToken).approve(address(helper), amount);
        helper.notifyReward(amount);
        vm.stopPrank();

        (address[] memory storedGauges, uint256[] memory amounts, uint256 epoch) = helper.getRewardByIndex(0);

        assertEq(storedGauges[0], gauges[0]);
        assertEq(storedGauges[1], gauges[1]);
        assertEq(amounts[0], weights[0] * amount / 10_000);
        assertEq(amounts[1], weights[1] * amount / 10_000);
        assertEq(epoch, (block.timestamp / 604800) * 604800);

        assertEq(helper.rewardHistoryLength(), 1);

        skip(1 weeks);

        (storedGauges, amounts, epoch) = helper.getLastReward();

        assertEq(storedGauges[0], gauges[0]);
        assertEq(storedGauges[1], gauges[1]);
        assertEq(amounts[0], weights[0] * amount / 10_000);
        assertEq(amounts[1], weights[1] * amount / 10_000);
        assertEq(epoch + 1 weeks, (block.timestamp / 1 weeks) * 1 weeks);
    }

    function testNotifyRewardWithoutGas() public {

        // Approve some gauges
        vm.startPrank(owner);
        helper.addApprovedGauge(makeAddr("gauge1"));
        helper.addApprovedGauge(makeAddr("gauge2"));
        vm.stopPrank();

        // Set weights
        address[] memory gauges = new address[](2) ;
        gauges[0] = makeAddr("gauge1");
        gauges[1] = makeAddr("gauge2");
        uint16[] memory weights = new uint16[](2) ;
        weights[0] = 6000;
        weights[1] = 4000;
        vm.startPrank(manager);
        helper.setWeights(gauges, weights);
        vm.stopPrank();

        // Deal reward tokens to notifier
        FakeToken(rewardToken).mint(rewardNotifier, 1000 ether);

        uint256 amount = 100 ether;

        vm.startPrank(rewardNotifier);
        IERC20(rewardToken).approve(address(helper), amount);
        vm.expectRevert(DepositHelper.NOT_ENOUGH_GAS.selector);
        helper.notifyReward(amount);
        vm.stopPrank();

    }

    function testNotifyRewardRevertIfNoWeights() public {
        vm.expectRevert(DepositHelper.NO_WEIGHTS.selector);
        vm.prank(rewardNotifier);
        helper.notifyReward(10 ether);
    }

}
