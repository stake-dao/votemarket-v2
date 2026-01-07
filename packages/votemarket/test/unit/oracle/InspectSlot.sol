// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@forge-std/src/Test.sol";

interface IPendleVotingController {
    function owner() external view returns (address);
}

contract InspectSlot is Test {
    address constant TARGET = 0x44087E105137a5095c008AaB6a6530182821F2F0;

    function setUp() public {
        vm.createSelectFork("mainnet", 22_829_942);
    }

    function testFindOwnerSlot() external {
        IPendleVotingController controller = IPendleVotingController(TARGET);
        address expectedOwner = controller.owner();

        for (uint256 i = 0; i < 20; i++) {
            bytes32 raw = vm.load(TARGET, bytes32(i));
            address decoded = address(uint160(uint256(raw)));

            if (decoded == expectedOwner) {
                break;
            }
        }
    }
}
