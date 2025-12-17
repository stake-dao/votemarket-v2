// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Script.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {Verifier} from "@votemarket/src/verifiers/Verifier.sol";
import {VerifierV2} from "@votemarket/src/verifiers/VerifierV2.sol";
import {VerifierPendle} from "@votemarket/src/verifiers/VerifierPendle.sol";

import {VerifierYB} from "@votemarket/src/verifiers/VerifierYB.sol";

interface ICreate3Factory {
    function deployCreate3(bytes32 salt, bytes memory code) external returns (address);
    function computeCreate3Address(bytes32 salt) external view returns (address);
}

abstract contract BaseV2 is Script {
    address public deployer = 0x428419Ad92317B09FE00675F181ac09c87D16450;
    //address public governance = 0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765;

    string[] public chains = ["polygon"];

    address public constant CREATE3_FACTORY = address(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    function deploy(
        address oracle,
        address gaugeController,
        bytes memory initCode,
        bytes32 salt,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public {
        for (uint256 i = 0; i < chains.length; i++) {
            vm.createSelectFork(vm.rpcUrl(chains[i]));
            vm.startBroadcast(deployer);

            ICreate3Factory(CREATE3_FACTORY).deployCreate3(salt, initCode);


            //Oracle(oracle).revokeAuthorizedDataProvider(address(oldVerifier));
            //Oracle(oracle).setAuthorizedDataProvider(address(verifierAddress));
            //Oracle(oracle).transferGovernance(address(governance));

            vm.stopBroadcast();
        }
    }

    /// @dev Returns the init code for the Verifier contract
    function getInitCode(
        address oracle,
        address gaugeController,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public pure virtual returns (bytes memory) {
        return abi.encodePacked(
            type(Verifier).creationCode,
            abi.encode(oracle, gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
        );
    }

    /// @dev Returns the init code for the Verifier contract
    /// V2 is for newer vyper versions.
    function getInitCodeV2(
        address oracle,
        address gaugeController,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public pure virtual returns (bytes memory) {
        return abi.encodePacked(
            type(VerifierV2).creationCode,
            abi.encode(oracle, gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
        );
    }

    function getInitCodePendle(
        address oracle,
        address gaugeController,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public pure virtual returns (bytes memory) {
        return abi.encodePacked(
            type(VerifierPendle).creationCode,
            abi.encode(oracle, gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
        );
    }

    function getInitCodeYb(
        address oracle,
        address gaugeController,
        uint256 lastUserVoteSlot,
        uint256 userSlopeSlot,
        uint256 weightSlot
    ) public pure virtual returns (bytes memory) {
        return abi.encodePacked(
            type(VerifierYB).creationCode,
            abi.encode(oracle, gaugeController, lastUserVoteSlot, userSlopeSlot, weightSlot)
        );
    }
}
