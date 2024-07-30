// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "forge-std/src/Test.sol";
import "forge-std/src/mocks/MockERC20.sol";

import "src/Votemarket.sol";

import "test/mocks/Hooks.sol";
import "test/unit/Base.t.sol";

contract ManageCampaignTest is BaseTest {
    function setUp() public override {
        BaseTest.setUp();
    }
}
