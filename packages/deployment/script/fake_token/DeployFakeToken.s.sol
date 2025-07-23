// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@forge-std/src/Script.sol";
import "./FakeToken.sol";

contract DeployFakeToken is Script {
    function run() external {
        vm.createSelectFork("arbitrum");
        vm.startBroadcast(address(0x428419Ad92317B09FE00675F181ac09c87D16450));

        // paramètres initiaux
        string memory name = "FakeToken";
        string memory symbol = "FAKE";
        uint8 decimals = 18;
        uint256 initialMint = 10_000 * 10 ** uint256(decimals);

        // déploiement
        FakeToken token = new FakeToken(name, symbol, decimals);

        // mint au déployeur
        token.mint(msg.sender, initialMint);

        vm.stopBroadcast();
    }
}