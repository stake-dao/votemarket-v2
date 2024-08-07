// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";
import "src/oracle/Oracle.sol";
import "src/oracle/OracleLens.sol";

import "test/mocks/Hooks.sol";

abstract contract BaseTest is Test {
    address creator = address(this);

    Oracle oracle;
    OracleLens oracleLens;

    MockERC20 rewardToken;
    Votemarket votemarket;

    // Test variables
    address HOOK;
    address[] blacklist;
    uint256 constant CHAIN_ID = 1;
    uint8 constant VALID_PERIODS = 4;
    address constant GAUGE = address(0x1234);
    address constant MANAGER = address(0x5678);
    uint256 constant MAX_REWARD_PER_VOTE = 100e18;
    uint256 constant TOTAL_REWARD_AMOUNT = 1000e18;

    function setUp() public virtual {
        oracle = new Oracle();
        oracleLens = new OracleLens(address(oracle));

        votemarket = new Votemarket();
        votemarket.setOracle(address(oracleLens));

        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        HOOK = address(new MockHook());

        oracle.setAuthorizedDataProvider(address(this));
        oracle.setAuthorizedBlockNumberProvider(address(this));

        /// To avoid timestamp = 0.
        skip(1 weeks);

        oracle.insertBlockNumber(votemarket.currentEpoch(), StateProofVerifier.BlockHeader({
            hash: blockhash(block.number),
            stateRootHash: bytes32(0),
            number: block.number,
            timestamp: block.timestamp
        }));

        _mockGaugeData(GAUGE, votemarket.currentEpoch());
        _mockAccountData(address(this), GAUGE, votemarket.currentEpoch());
    }

    function _createCampaign() internal {
        deal(address(rewardToken), creator, TOTAL_REWARD_AMOUNT);
        rewardToken.approve(address(votemarket), TOTAL_REWARD_AMOUNT);

        votemarket.createCampaign(
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

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setFee(fee);

        vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        votemarket.setFee(1e18);

        /// Claim deadline.
        uint256 claimDeadline = 3 weeks;
        votemarket.setClaimDeadline(claimDeadline);
        assertEq(votemarket.claimDeadline(), claimDeadline);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setClaimDeadline(claimDeadline);

        /// Close deadline.
        uint256 closeDeadline = 3 weeks;
        votemarket.setCloseDeadline(closeDeadline);
        assertEq(votemarket.closeDeadline(), closeDeadline);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Votemarket.AUTH_GOVERNANCE_ONLY.selector);
        votemarket.setCloseDeadline(closeDeadline);
    }

    function testGetters() public {
        _createCampaign();
        uint256 campaignId = votemarket.campaignCount() - 1;

        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 4);
        skip(4 weeks);
        assertEq(votemarket.getRemainingPeriods(campaignId, votemarket.currentEpoch()), 0);
    }

    function _updateEpochs(uint256 campaignId) internal {
        /// Get the campaign.
        Campaign memory campaign = votemarket.getCampaign(campaignId);
        uint256 endTimestamp = campaign.endTimestamp;
        uint256 startTimestamp = endTimestamp - campaign.numberOfPeriods * 1 weeks;

        for (uint256 i = startTimestamp; i < endTimestamp; i += 1 weeks) {
            votemarket.updateEpoch(campaignId, i);

            /// Get the campaign.
            campaign = votemarket.getCampaign(campaignId);
            endTimestamp = campaign.endTimestamp;
        }
    }

    function _mockGaugeData(address gauge, uint256 epoch) internal {
        oracle.insertPoint(gauge, epoch, Oracle.Point({bias: 10e18, slope: 1e18, lastUpdate: block.timestamp}));
    }

    function _mockAccountData(address account, address gauge, uint256 epoch) internal {
        oracle.insertAddressEpochData(
            account,
            gauge,
            epoch,
            Oracle.VotedSlope({slope: 1e18, power: 1e18, end: epoch, lastVote: 0, lastUpdate: block.timestamp})
        );
    }
}
