// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {LeftoverDistributorHook} from "@periphery/src/hooks/LeftoverDistributorHook.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt, address deployer) external view returns (address);
}

contract Deploy is Script {
    address public deployer = 0x606A503e5178908F10597894B35b2Be8685EAB90;
    address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    address public oracle = 0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8;

    address public CRV_VOTEMARKET = 0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9;
    address public BAL_VOTEMARKET = 0xDD2FaD5606cD8ec0c3b93Eb4F9849572b598F4c7;
    address public FXN_VOTEMARKET = 0x155a7Cf21F8853c135BdeBa27FEA19674C65F2b4;

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    string[] public chains = ["arbitrum", "optimism", "base", "polygon"];

    function run() public {
        // Generate a random seed for the deterministic deployment of the protocol
        bytes8 randomSeed = bytes8(uint64(vm.randomUint()));

        // This prefix is the same for all the deployments across all chains.
        string memory saltPrefix =
            string.concat("STAKEDAO.VOTEMARKET.V2.COMMON.", vm.toString(abi.encodePacked(randomSeed)), ".");

        // This is the salt for the deployment of the leftover distributor hook.
        bytes32 salt = keccak256(abi.encodePacked(saltPrefix, type(LeftoverDistributorHook).name));

        bytes memory initCode = abi.encodePacked(type(LeftoverDistributorHook).creationCode, abi.encode(deployer));

        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));

            initCode = abi.encodePacked(type(LeftoverDistributorHook).creationCode, abi.encode(deployer));

            vm.startBroadcast(deployer);
            address leftoverDistributorHook = ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);

            LeftoverDistributorHook(leftoverDistributorHook).enableVotemarket(CRV_VOTEMARKET);
            LeftoverDistributorHook(leftoverDistributorHook).enableVotemarket(BAL_VOTEMARKET);
            LeftoverDistributorHook(leftoverDistributorHook).enableVotemarket(FXN_VOTEMARKET);

            LeftoverDistributorHook(leftoverDistributorHook).transferGovernance(governance);

            vm.stopBroadcast();
        }
    }
}
