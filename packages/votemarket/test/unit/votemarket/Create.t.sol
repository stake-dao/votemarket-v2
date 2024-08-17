// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

/// Testing contracts & libraries
import "test/unit/votemarket/Base.t copy.sol";

contract CreateCampaignTest is BaseCopyTest {
    using EnumerableSetLib for EnumerableSetLib.AddressSet;

    EnumerableSetLib.AddressSet set;
    uint256 private constant _ZERO_SENTINEL = 0xfbb67fda52d4bfb8bf;

    struct CampaignCreationParams {
        uint256 chainId;
        address gauge;
        address manager;
        address rewardToken;
        uint8 numberOfPeriods;
        uint256 maxRewardPerVote;
        uint256 totalRewardAmount;
        address[] addresses;
        address hook;
        bool whitelist;
    }

    function testCreateCampaignCopy(CampaignCreationParams memory params) public {
        vm.assume(params.numberOfPeriods < 50);

        /// Clean addresses from Sentil Value (EnumerableSetLib.AddressSet)
        params.addresses = _getCleanAddresses(params.addresses);

        vm.startPrank(params.manager);

        deal(address(rewardToken), params.manager, params.totalRewardAmount);
        rewardToken.approve(address(votemarket), params.totalRewardAmount);

        if (params.numberOfPeriods < minimiumPeriodsSize) {
            vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        } else if (params.totalRewardAmount == 0 || params.maxRewardPerVote == 0) {
            vm.expectRevert(Votemarket.ZERO_INPUT.selector);
        } else if (params.gauge == address(0)) {
            vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        } else if (params.addresses.length > maxAddressesSize) {
            vm.expectRevert(Votemarket.INVALID_INPUT.selector);
        } else if(params.rewardToken == address(0)) {
            rewardToken = MockERC20(address(0));
            vm.expectRevert(Votemarket.ZERO_ADDRESS.selector);
        }

        uint256 campaignId = votemarket.createCampaign(
            params.chainId,
            params.gauge,
            params.manager,
            address(rewardToken),
            params.numberOfPeriods,
            params.maxRewardPerVote,
            params.totalRewardAmount,
            params.addresses,
            params.hook,
            params.whitelist
        );

        vm.stopPrank();

        uint256 campaignCount = votemarket.campaignCount();

        /// The call was successful.
        if (campaignCount == 1) {
            uint256 currentEpoch = votemarket.currentEpoch();
            Campaign memory campaign = votemarket.getCampaign(campaignId);

            assertEq(campaign.chainId, params.chainId);
            assertEq(campaign.gauge, params.gauge);
            assertEq(campaign.manager, params.manager);
            assertEq(campaign.rewardToken, address(rewardToken));
            assertEq(campaign.numberOfPeriods, params.numberOfPeriods);
            assertEq(campaign.maxRewardPerVote, params.maxRewardPerVote);
            assertEq(campaign.totalRewardAmount, params.totalRewardAmount);
            assertEq(campaign.startTimestamp, currentEpoch + votemarket.EPOCH_LENGTH());
            assertEq(
                campaign.endTimestamp, campaign.startTimestamp + params.numberOfPeriods * votemarket.EPOCH_LENGTH()
            );

            /// The first period before the start should be empty.
            Period memory period = votemarket.getPeriodPerCampaign(campaignId, currentEpoch);
            assertEq(period.rewardPerPeriod, 0);
            assertEq(period.hook, address(0));

            address[] memory addresses = votemarket.getAddressesByCampaign(campaignId, currentEpoch);
            assertEq(addresses.length, 0);

            uint256 length = _getRealNumberOfAddresses(params.addresses);

            period = votemarket.getPeriodPerCampaign(campaignId, campaign.startTimestamp);
            uint256 rewardPerPeriod = FixedPointMathLib.mulDiv(params.totalRewardAmount, 1, params.numberOfPeriods);
            assertEq(period.rewardPerPeriod, rewardPerPeriod);

            for (uint256 i = campaign.startTimestamp; i < campaign.endTimestamp; i += votemarket.EPOCH_LENGTH()) {
                period = votemarket.getPeriodPerCampaign(campaignId, i);
                addresses = votemarket.getAddressesByCampaign(campaignId, i);
                assertEq(period.hook, params.hook);
                assertEq(addresses.length, length);
            }
        }
    }

    function _getCleanAddresses(address[] memory addresses) internal pure returns (address[] memory) {
        address[] memory cleanAddresses = new address[](addresses.length);
        uint256 cleanAddressesLength = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] != address(uint160(_ZERO_SENTINEL))) {
                cleanAddresses[cleanAddressesLength] = addresses[i];
                cleanAddressesLength++;
            }
        }
        return cleanAddresses;
    }

    function _getRealNumberOfAddresses(address[] memory addresses) internal returns (uint256 length) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] != address(0) && addresses[i] != address(uint160(_ZERO_SENTINEL))) {
                set.add(addresses[i]);
            }
        }
        length = set.length();

        delete set;
    }
}
