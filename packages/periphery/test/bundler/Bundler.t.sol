// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@forge-std/src/mocks/MockERC20.sol";

import "src/bundler/Bundler.sol";

import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {Verifier} from "@votemarket/src/verifiers/Verifier.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {OracleLens} from "@votemarket/src/oracle/OracleLens.sol";

contract BundlerTest is Test {
    address constant deployer = 0x000755Fbe4A24d7478bfcFC1E561AfCE82d1ff62;
    address constant CRV_ACCOUNT = 0xDBA2Cba9F62Cf1eF07B3664Ee1da3663c86c38d0;

    Bundler multicaller;

    address laPoste = 0x0000560000d413A8Fe7635DF64AeA4D077cb0000;

    Votemarket votemarket = Votemarket(0x5e5C922a5Eeab508486eB906ebE7bDFFB05D81e5);
    Verifier verifier = Verifier(0x2Fa15A44eC5737077a747ed93e4eBD5b4960a465);
    Oracle oracle = Oracle(0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8);
    OracleLens oracleLens = OracleLens(0x99EDB5782da5D799dd16a037FDbc00a1494b9Ead);

    address fCRV = 0xBfa5aE960D899bA65A1bE34905ba3981b1e2E6b7;
    address fCRVWrapped = 0x6ac7FCC24eb898d99FA10841336FCB5C82Bcfaa5;

    address fUSDC = 0xF87c21CeAD0790BC3B28E951D41710fB48F7Fd29;
    address fUSDCWrapped = 0x193dc2E06FBB2C68493Bca95a6d5a51d6df94125;

    function setUp() public {
        vm.createSelectFork("arbitrum", 269_944_467);

        multicaller = new Bundler(laPoste);
    }

    function test_multicall() public {
        uint256 epoch = votemarket.currentEpoch();

        address[] memory tokens = new address[](2);
        tokens[0] = fCRV;
        tokens[1] = fUSDC;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 500_000e18;
        amounts[1] = 500_000e6;

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSignature(
            "claim(address,uint256,address,uint256,bytes)", address(votemarket), 0, CRV_ACCOUNT, epoch, new bytes(0)
        );
        data[1] = abi.encodeWithSelector(Bridge.bridge.selector, tokens, amounts, 1, 350_000, deployer);

        vm.prank(deployer);
        MockERC20(fCRVWrapped).approve(address(multicaller), type(uint256).max);

        vm.prank(deployer);
        MockERC20(fUSDCWrapped).approve(address(multicaller), type(uint256).max);

        vm.prank(deployer);
        multicaller.multicall{value: 0.02 ether}(data);
    }
}
