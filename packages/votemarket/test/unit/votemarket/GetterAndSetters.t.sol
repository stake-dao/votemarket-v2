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

    function testInitialSetup() public {
        Votemarket newVotemarket = new Votemarket({
            _governance: address(this),
            _oracle: address(oracleLens),
            _feeCollector: address(this),
            _epochLength: 1 weeks,
            _minimumPeriods: 2
        });

        assertEq(newVotemarket.governance(), address(this));
        assertEq(newVotemarket.feeCollector(), address(this));
        assertEq(newVotemarket.fee(), 4e16);

        assertEq(newVotemarket.ORACLE(), address(oracleLens));
        assertEq(newVotemarket.EPOCH_LENGTH(), 1 weeks);
        assertEq(newVotemarket.MINIMUM_PERIODS(), 2);
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

        vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        votemarket.setRemote(address(0));

        votemarket.setRemote(feeCollector);
        assertEq(votemarket.remote(), remote);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setRemote(remote);

        votemarket.setCustomFee(address(0xCAFE), 100);
        assertEq(votemarket.customFeeByManager(address(0xCAFE)), 100);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setCustomFee(address(0xCAFE), 100);

        vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        votemarket.setCustomFee(address(0xCAFE), 100e18);

        votemarket.setRecipient(address(0xCAFE));
        assertEq(votemarket.recipients(address(this)), address(0xCAFE));

        votemarket.setRecipient(address(0xCAFE), address(0xBEEF));
        assertEq(votemarket.recipients(address(0xCAFE)), address(0xBEEF));

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setRecipient(address(0xCAFE), address(0xBEEF));

        votemarket.setIsProtected(address(0xCAFE), true);
        assertEq(votemarket.isProtected(address(0xCAFE)), true);

        votemarket.setIsProtected(address(0xCAFE), false);
        assertEq(votemarket.isProtected(address(0xCAFE)), false);

        vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        votemarket.transferGovernance(address(0));

        votemarket.transferGovernance(address(0xBEEF));

        assertEq(votemarket.governance(), address(this));
        assertEq(votemarket.futureGovernance(), address(0xBEEF));

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.transferGovernance(address(0xBEEF));

        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.acceptGovernance();

        vm.prank(address(0xBEEF));
        votemarket.acceptGovernance();

        assertEq(votemarket.governance(), address(0xBEEF));
        assertEq(votemarket.futureGovernance(), address(0));
    }

    function testGetters() public {
        _createCampaign();

        /// Skip to the start timestamp.
        skip(1 weeks);

        campaignId = votemarket.campaignCount() - 1;

        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 4);
        skip(4 weeks);
        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 0);
    }
}
