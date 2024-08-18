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
    uint256 CHAIN_ID = 1;
    uint8 VALID_PERIODS = 4;
    address GAUGE = address(0x1234);
    address MANAGER = address(0x5678);
    uint256 MAX_REWARD_PER_VOTE = 1e18;
    uint256 TOTAL_REWARD_AMOUNT = 1000e18;

    uint256 TOTAL_VOTES = 2000e18;
    uint256 ACCOUNT_VOTES = 1000e18;

    uint256 maxAddressesSize;
    uint256 minimiumPeriodsSize;

    function setUp() public virtual {
        /// To avoid timestamp = 0.
        skip(1 weeks);

        oracleLens = new MockOracleLens();
        votemarket = new Votemarket({
            _governance: address(this),
            _oracle: address(oracleLens),
            _feeCollector: address(this),
            _epochLength: 1 weeks,
            _minimumPeriods: 2
        });

        minimiumPeriodsSize = votemarket.MINIMUM_PERIODS();
        maxAddressesSize = votemarket.MAX_ADDRESSES_PER_CAMPAIGN();

        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        HOOK = address(new MockHook(address(rewardToken)));
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

    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
