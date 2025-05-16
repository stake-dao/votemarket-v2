// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@solady/src/auth/Ownable.sol";

import {FakeToken} from "test/mocks/FakeToken.sol";
import {ILaPoste} from "src/interfaces/ILaPoste.sol";
import {MockOracleLens} from "@votemarket/test/mocks/OracleLens.sol";
import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {IVotemarket} from "@votemarket/src/interfaces/IVotemarket.sol";

import {Oracle} from "@votemarket/src/oracle/Oracle.sol";
import {VMGovernanceHub, Remote} from "src/remote/VMGovernanceHub.sol";

contract VMGovernanceHubTest is Test {
    VMGovernanceHub public vmGovernanceHub;

    Votemarket votemarket;
    Oracle oracle;

    function setUp() public {
        vmGovernanceHub =
            new VMGovernanceHub({_laPoste: address(this), _tokenFactory: address(this), _owner: address(this)});

        votemarket = new Votemarket({
            _governance: address(vmGovernanceHub),
            _oracle: address(this),
            _feeCollector: address(this),
            _epochLength: 1 weeks,
            _minimumPeriods: 2
        });

        oracle = new Oracle({_governance: address(vmGovernanceHub)});

        address[] memory votemarkets = new address[](1);
        votemarkets[0] = address(votemarket);

        uint256[] memory destinationChainIds = new uint256[](1);
        destinationChainIds[0] = 42161;

        address[] memory oracleAddresses = new address[](1);
        oracleAddresses[0] = address(oracle);

        vmGovernanceHub.setVotemarkets(votemarkets, 100000);
        vmGovernanceHub.setOracles(oracleAddresses, 100000);
        vmGovernanceHub.setDestinationChainIds(destinationChainIds, 100000);
    }

    ////////////////////////////////////////////////////////////////
    /// --- MOCKED FUNCTIONS
    ///////////////////////////////////////////////////////////////

    function test_permissions() public {
        address[] memory accounts = new address[](1);
        accounts[0] = address(0xCAFE);

        vm.chainId(1);

        vm.prank(address(0xCAFE));
        vm.expectRevert(Ownable.Unauthorized.selector);
        vmGovernanceHub.setIsProtected(address(votemarket), accounts, true, 100000);

        vm.chainId(42161);

        vm.prank(address(0xCAFE));
        vm.expectRevert(Remote.InvalidChainId.selector);
        vmGovernanceHub.setIsProtected(address(votemarket), accounts, true, 100000);

        vm.chainId(1);
        vmGovernanceHub.setIsProtected(address(votemarket), accounts, true, 100000);

        vm.chainId(1);
        vm.expectRevert(Remote.InvalidChainId.selector);
        vmGovernanceHub.receiveMessage(10, address(this), "");

        vm.chainId(42161);
        vm.expectRevert(Remote.InvalidSender.selector);
        vmGovernanceHub.receiveMessage(1, address(this), "");

        vm.chainId(42161);
        vm.prank(address(vmGovernanceHub));
        vm.expectRevert(Remote.NotLaPoste.selector);
        vmGovernanceHub.receiveMessage(1, address(this), "");
    }

    function test_receiveMessage_setIsProtected() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(0xCAFE);
        accounts[1] = address(0xBEEF);

        bytes memory parameters = abi.encode(address(votemarket), accounts, true);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_IS_PROTECTED, parameters: parameters})
        );

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(votemarket.isProtected(accounts[0]), true);
        assertEq(votemarket.isProtected(accounts[1]), true);

        parameters = abi.encode(address(votemarket), accounts, false);
        payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_IS_PROTECTED, parameters: parameters})
        );

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(votemarket.isProtected(accounts[0]), false);
        assertEq(votemarket.isProtected(accounts[1]), false);
    }

    function test_receiveMessage_setRemote() public {
        address remote = address(0xBEEF);
        bytes memory parameters = abi.encode(remote);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_REMOTE, parameters: parameters})
        );

        assertEq(votemarket.remote(), address(0));
        receiveMessage(1, address(vmGovernanceHub), payload);
        assertEq(votemarket.remote(), remote);
    }

    function test_receiveMessage_setFee() public {
        uint256 fee = 0.1e18;
        bytes memory parameters = abi.encode(fee);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_FEE, parameters: parameters})
        );

        /// Default fee is 4%.
        assertEq(votemarket.fee(), 4e16);
        receiveMessage(1, address(vmGovernanceHub), payload);
        assertEq(votemarket.fee(), fee);
    }

    function test_receiveMessage_setCustomFee() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(0xCAFE);
        accounts[1] = address(0xBEEF);

        uint256[] memory fees = new uint256[](2);
        fees[0] = 0.1e18;
        fees[1] = 0.1e18;

        bytes memory parameters = abi.encode(address(votemarket), accounts, fees);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_CUSTOM_FEE, parameters: parameters})
        );

        assertEq(votemarket.customFeeByManager(accounts[0]), 0);
        assertEq(votemarket.customFeeByManager(accounts[1]), 0);

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(votemarket.customFeeByManager(accounts[0]), fees[0]);
        assertEq(votemarket.customFeeByManager(accounts[1]), fees[1]);
    }

    function test_receiveMessage_setRecipient() public {
        address[] memory accounts = new address[](2);
        accounts[0] = address(0xCAFE);
        accounts[1] = address(0xBEEF);

        address recipient = address(0xDEAD);
        bytes memory parameters = abi.encode(address(votemarket), accounts, recipient);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_RECIPIENT, parameters: parameters})
        );

        assertEq(votemarket.recipients(accounts[0]), address(0));
        assertEq(votemarket.recipients(accounts[1]), address(0));

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(votemarket.recipients(accounts[0]), recipient);
        assertEq(votemarket.recipients(accounts[1]), recipient);
    }

    function test_receiveMessage_setFeeCollector() public {
        address feeCollector = address(0xBEEF);
        bytes memory parameters = abi.encode(feeCollector);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.SET_FEE_COLLECTOR, parameters: parameters})
        );

        assertEq(votemarket.feeCollector(), address(this));
        receiveMessage(1, address(vmGovernanceHub), payload);
        assertEq(votemarket.feeCollector(), feeCollector);
    }

    function test_receiveMessage_transferGovernance() public {
        address futureGovernance = address(0xBEEF);
        bytes memory parameters = abi.encode(futureGovernance);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.TRANSFER_VOTEMARKET_GOVERNANCE,
                parameters: parameters
            })
        );

        assertEq(votemarket.futureGovernance(), address(0));
        receiveMessage(1, address(vmGovernanceHub), payload);
        assertEq(votemarket.futureGovernance(), futureGovernance);
    }

    function test_receiveMessage_acceptGovernance() public {
        vm.prank(address(vmGovernanceHub));
        votemarket.transferGovernance(address(0xBEEF));

        vm.prank(address(0xBEEF));
        votemarket.acceptGovernance();

        assertEq(votemarket.governance(), address(0xBEEF));

        vm.prank(address(0xBEEF));
        votemarket.transferGovernance(address(vmGovernanceHub));

        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.ACCEPT_VOTEMARKET_GOVERNANCE,
                parameters: ""
            })
        );

        assertEq(votemarket.governance(), address(0xBEEF));
        assertEq(votemarket.futureGovernance(), address(vmGovernanceHub));

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(votemarket.governance(), address(vmGovernanceHub));
        assertEq(votemarket.futureGovernance(), address(0));
    }

    function test_receiveMessage_setAuthorizedBlockNumberProvider() public {
        address blockNumberProvider = address(0xBEEF);
        bytes memory parameters = abi.encode(address(oracle), blockNumberProvider);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.SET_AUTHORIZED_BLOCK_NUMBER_PROVIDER,
                parameters: parameters
            })
        );

        assertEq(oracle.authorizedBlockNumberProviders(blockNumberProvider), false);

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(oracle.authorizedBlockNumberProviders(blockNumberProvider), true);
    }

    function test_receiveMessage_revokeAuthorizedBlockNumberProvider() public {
        vm.prank(address(vmGovernanceHub));
        oracle.setAuthorizedBlockNumberProvider(address(0xBEEF));

        address blockNumberProvider = address(0xBEEF);
        bytes memory parameters = abi.encode(address(oracle), blockNumberProvider);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.REVOKE_AUTHORIZED_BLOCK_NUMBER_PROVIDER,
                parameters: parameters
            })
        );

        assertEq(oracle.authorizedBlockNumberProviders(blockNumberProvider), true);

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(oracle.authorizedBlockNumberProviders(blockNumberProvider), false);
    }

    function test_receiveMessage_setAuthorizedDataProvider() public {
        address dataProvider = address(0xBEEF);
        bytes memory parameters = abi.encode(address(oracle), dataProvider);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.SET_AUTHORIZED_DATA_PROVIDER,
                parameters: parameters
            })
        );

        assertEq(oracle.authorizedDataProviders(dataProvider), false);

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(oracle.authorizedDataProviders(dataProvider), true);
    }

    function test_receiveMessage_revokeAuthorizedDataProvider() public {
        vm.prank(address(vmGovernanceHub));
        oracle.setAuthorizedDataProvider(address(0xBEEF));

        address dataProvider = address(0xBEEF);
        bytes memory parameters = abi.encode(address(oracle), dataProvider);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.REVOKE_AUTHORIZED_DATA_PROVIDER,
                parameters: parameters
            })
        );

        assertEq(oracle.authorizedDataProviders(dataProvider), true);

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(oracle.authorizedDataProviders(dataProvider), false);
    }

    function test_receiveMessage_transferOracleGovernance() public {
        address futureGovernance = address(0xBEEF);
        bytes memory parameters = abi.encode(futureGovernance);
        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({
                actionType: VMGovernanceHub.ActionType.TRANSFER_ORACLE_GOVERNANCE,
                parameters: parameters
            })
        );

        assertEq(oracle.futureGovernance(), address(0));
        receiveMessage(1, address(vmGovernanceHub), payload);
        assertEq(oracle.futureGovernance(), futureGovernance);
    }

    function test_receiveMessage_acceptOracleGovernance() public {
        vm.prank(address(vmGovernanceHub));
        oracle.transferGovernance(address(0xBEEF));

        vm.prank(address(0xBEEF));
        oracle.acceptGovernance();

        assertEq(oracle.governance(), address(0xBEEF));

        vm.prank(address(0xBEEF));
        oracle.transferGovernance(address(vmGovernanceHub));

        bytes memory payload = abi.encode(
            VMGovernanceHub.Payload({actionType: VMGovernanceHub.ActionType.ACCEPT_ORACLE_GOVERNANCE, parameters: ""})
        );

        assertEq(oracle.governance(), address(0xBEEF));
        assertEq(oracle.futureGovernance(), address(vmGovernanceHub));

        receiveMessage(1, address(vmGovernanceHub), payload);

        assertEq(oracle.governance(), address(vmGovernanceHub));
        assertEq(oracle.futureGovernance(), address(0));
    }

    function sendMessage(ILaPoste.MessageParams memory params, uint256 additionalGasLimit, address refundAddress)
        external
        payable
    {}

    function receiveMessage(uint256 chainId, address sender, bytes memory payload) public {
        vmGovernanceHub.receiveMessage(chainId, sender, payload);
    }

    function tokenFactory() external view returns (address) {
        return address(this);
    }
}
