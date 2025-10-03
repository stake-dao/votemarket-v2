// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@solady/src/auth/Ownable.sol";

import {FakeToken} from "test/mocks/FakeToken.sol";
import {ILaPoste} from "src/interfaces/ILaPoste.sol";
import {IncentiveGaugeHook} from "src/hooks/IncentiveGaugeHook.sol";
import {MockOracleLens} from "@votemarket/test/mocks/OracleLens.sol";
import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {IVotemarket} from "@votemarket/src/interfaces/IVotemarket.sol";
import {CampaignRemoteManager} from "src/remote/CampaignRemoteManager.sol";

contract IncentiveGaugeHookTest is Test {
    CampaignRemoteManager public campaignRemoteManager;

    IncentiveGaugeHook public incentiveGaugeHook;

    MockOracleLens oracleLens;

    FakeToken rewardToken;
    FakeToken wrappedToken;

    Votemarket votemarket;

    address public GAUGE = address(0xBEEF);
    address public DEAD = address(0xDEAD);
    uint256 public NB_VOTES = 5e18;
    address public MERKL = address(this);

    function setUp() public {
        rewardToken = new FakeToken("Mock Token", "MOCK", 18);
        wrappedToken = new FakeToken("Wrapped Token", "WMOCK", 18);

        oracleLens = new MockOracleLens();
        votemarket = new Votemarket({
            _governance: address(this),
            _oracle: address(oracleLens),
            _feeCollector: address(this),
            _epochLength: 1 weeks,
            _minimumPeriods: 2
        });

        incentiveGaugeHook = new IncentiveGaugeHook(address(this), 7*3600, MERKL);

        campaignRemoteManager =
            new CampaignRemoteManager({_laPoste: address(this), _tokenFactory: address(this), _owner: address(this)});

        votemarket.setRemote(address(campaignRemoteManager));

        rewardToken.mint(address(this), 1000e18);

        // Whitelist the votemarket platform
        campaignRemoteManager.setPlatformWhitelist(address(votemarket), true);
        incentiveGaugeHook.enableVotemarket(address(votemarket));
    }

    function test_CampaignManagement() public {
        // Test to create the campaign on mainnet
        CampaignRemoteManager.CampaignCreationParams memory params = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: GAUGE,
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(incentiveGaugeHook),
            isWhitelist: false
        });

        vm.chainId(42161);

        vm.expectRevert(CampaignRemoteManager.InvalidChainId.selector);
        campaignRemoteManager.createCampaign(params, 10, 100000, address(votemarket));

        vm.chainId(1);

        rewardToken.approve(address(campaignRemoteManager), 1000e18);
        campaignRemoteManager.createCampaign(params, 10, 100000, address(votemarket));

        assertEq(rewardToken.balanceOf(address(this)), 0);
        assertEq(rewardToken.balanceOf(address(campaignRemoteManager)), 0);
        assertEq(rewardToken.balanceOf(address(0xCAFE)), 1000e18);

        // Create campaign on arb through message receiving
        vm.chainId(42161);
        bytes memory createParameters = abi.encode(params);
        bytes memory createPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CREATE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: createParameters
            })
        );

        wrappedToken.mint(address(campaignRemoteManager), params.totalRewardAmount);
        receiveMessage(1, address(campaignRemoteManager), createPayload);

        skip(1 weeks); // Skip to start of campaign

        // Set some votes (not much to not reach the max price)
        oracleLens.setTotalVotes(GAUGE, 0, NB_VOTES);

        // Update the campaign to run the hook
        address hook = votemarket.getCampaign(0).hook;
        assertEq(hook, address(incentiveGaugeHook));

        uint256 startTimestamp = votemarket.getCampaign(0).startTimestamp;
        votemarket.updateEpoch(0, startTimestamp, "");

        uint256 rewardPerPeriod = votemarket.getPeriodPerCampaign(0, startTimestamp).rewardPerPeriod;
        assertTrue(votemarket.getPeriodPerCampaign(0, startTimestamp).updated);

        // The hook should have the leftOver
        uint256 currentEpoch = votemarket.currentEpoch();
        uint256 nbPendingIncentives = incentiveGaugeHook.getPendingIncentivesCount(currentEpoch, address(votemarket));
        assertEq(1, nbPendingIncentives);
        assertEq(wrappedToken.balanceOf(address(incentiveGaugeHook)), rewardPerPeriod-NB_VOTES);

        // Check pending incentive
        uint256 amount = incentiveGaugeHook.getPendingIncentive(currentEpoch, address(votemarket), 0).leftover;
        assertEq(wrappedToken.balanceOf(address(incentiveGaugeHook)), amount);
        assertEq(amount, rewardPerPeriod-NB_VOTES);

        // Bridge incentive funds
        incentiveGaugeHook.bridgeAll(address(votemarket), currentEpoch, 1_000_000);

        // Should have 1 pending but everything at 0
        nbPendingIncentives = incentiveGaugeHook.getPendingIncentivesCount(currentEpoch, address(votemarket));
        assertEq(1, nbPendingIncentives);
        amount = incentiveGaugeHook.getPendingIncentive(currentEpoch, address(votemarket), 0).leftover;
        assertEq(0, amount);
    }

    function sendMessage(ILaPoste.MessageParams memory params, uint256 additionalGasLimit, address refundAddress)
        external
        payable
    {
        // If it's the hook, burn wrapped token and send to the merkl the funds
        if(msg.sender == address(incentiveGaugeHook)) {
            for (uint256 i = 0; i < params.tokens.length; i++) {
                wrappedToken.burn(msg.sender, params.tokens[i].amount);

                vm.prank(address(0xCAFE));
                rewardToken.transfer(MERKL, params.tokens[i].amount);
            }
        } else {
            for (uint256 i = 0; i < params.tokens.length; i++) {
                rewardToken.transferFrom(msg.sender, address(0xCAFE), params.tokens[i].amount);
            }
        }
    }

    function receiveMessage(uint256 chainId, address sender, bytes memory payload) public {
        campaignRemoteManager.receiveMessage(chainId, sender, payload);
    }

    function wrappedTokens(address token) external view returns (address) {
        return address(wrappedToken);
    }

    function nativeTokens(address wrappedToken) external view returns (address) {
        return address(rewardToken);
    }

    function tokenFactory() external view returns (address) {
        return address(this);
    }
}
