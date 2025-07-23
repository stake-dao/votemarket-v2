// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@forge-std/src/Script.sol";
import {MockERC20} from "@forge-std/src/mocks/MockERC20.sol";
import {Votemarket} from "@votemarket/src/Votemarket.sol";

contract CreateTestCampaign is Script {

    address deployer = address(0x428419Ad92317B09FE00675F181ac09c87D16450);
    address votemarket = address(0x3B3500439D8F781015cB99Bab4573bf452b170E2);
    address token = address(0x787A4E064fB3B2fDE990dA3A266A91d326fce34c);
    address gauge = address(0xC64D59eb11c869012C686349d24e1D7C91C86ee2);
    address[] blacklist;
    address HOOK;

    function run() external {
        vm.createSelectFork("arbitrum");
        vm.startBroadcast(deployer);

        
        MockERC20(token).approve(votemarket, 100000 ether);
        
        Votemarket(votemarket).createCampaign(
            42161, 
            gauge, 
            deployer, 
            token, 
            2, 
            1 ether, 
            10 ether, 
            blacklist, 
            HOOK, 
            false);
        

        vm.stopBroadcast();
    }
}