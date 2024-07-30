// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/src/Test.sol";
import "forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";
import "test/mocks/Hooks.sol";

abstract contract BaseTest is Test {
    address creator = address(this);
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
        votemarket = new Votemarket();
        rewardToken = new MockERC20();
        rewardToken.initialize("Mock Token", "MOCK", 18);

        HOOK = address(new MockHook());
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
}