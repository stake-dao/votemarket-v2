// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import "@forge-std/src/Test.sol";
import "@solady/src/auth/Ownable.sol";

import {FakeToken} from "test/mocks/FakeToken.sol";
import {ILaPoste} from "src/interfaces/ILaPoste.sol";
import {MockOracleLens} from "@votemarket/test/mocks/OracleLens.sol";
import {Votemarket} from "@votemarket/src/Votemarket.sol";
import {IVotemarket} from "@votemarket/src/interfaces/IVotemarket.sol";
import {CampaignRemoteManager} from "src/remote/CampaignRemoteManager.sol";

contract CampaignRemoteManagerTest is Test {
    CampaignRemoteManager public campaignRemoteManager;

    MockOracleLens oracleLens;

    FakeToken rewardToken;
    FakeToken wrappedToken;

    Votemarket votemarket;

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

        campaignRemoteManager =
            new CampaignRemoteManager({_laPoste: address(this), _tokenFactory: address(this), _owner: address(this)});

        votemarket.setRemote(address(campaignRemoteManager));

        rewardToken.mint(address(this), 1000e18);

        // Whitelist the votemarket platform
        campaignRemoteManager.setPlatformWhitelist(address(votemarket), true);
    }

    function test_getInitCodehash() public {
        // 0x8898502ba35ab64b3562abc509befb7eb178d4df75e47f6342d5279f66004005 => 0x000000009dF57105d76B059178989E01356e4b45 => 256
        bytes memory args = abi.encode(
            0xF0000058000021003E4754dCA700C766DE7601C2,
            0x96006425Da428E45c282008b00004a00002B345e,
            0xB0552b6860CE5C0202976Db056b5e3Cc4f9CC765
        );
        bytes memory bytecode = abi.encodePacked(type(CampaignRemoteManager).creationCode, args);
        console.logBytes32(keccak256(bytecode));
    }

    function test_CampaignManagement() public {
        CampaignRemoteManager.CampaignCreationParams memory params = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: address(0xBEEF),
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1000e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(0),
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

        CampaignRemoteManager.CampaignManagementParams memory managementParams = CampaignRemoteManager
            .CampaignManagementParams({
            campaignId: 1,
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            totalRewardAmount: 1000e18,
            maxRewardPerVote: 1000e18
        });

        rewardToken.mint(address(this), 1000e18);
        rewardToken.approve(address(campaignRemoteManager), 1000e18);

        vm.chainId(42161);
        vm.expectRevert(CampaignRemoteManager.InvalidChainId.selector);
        campaignRemoteManager.manageCampaign(managementParams, 10, 100000, address(votemarket));

        vm.chainId(1);
        campaignRemoteManager.manageCampaign(managementParams, 10, 100000, address(votemarket));

        assertEq(rewardToken.balanceOf(address(this)), 0);
        assertEq(rewardToken.balanceOf(address(campaignRemoteManager)), 0);
        assertEq(rewardToken.balanceOf(address(0xCAFE)), 2000e18);
    }

    function test_CampaignClosing() public {
        CampaignRemoteManager.CampaignClosingParams memory params =
            CampaignRemoteManager.CampaignClosingParams({campaignId: 1});

        vm.chainId(42161);
        vm.expectRevert(CampaignRemoteManager.InvalidChainId.selector);
        campaignRemoteManager.closeCampaign(params, 10, 100000, address(votemarket));

        vm.chainId(1);
        campaignRemoteManager.closeCampaign(params, 10, 100000, address(votemarket));
    }

    function test_receiveMessage() public {
        CampaignRemoteManager.CampaignCreationParams memory params = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: address(0xBEEF),
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1000e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(0),
            isWhitelist: false
        });

        bytes memory parameters = abi.encode(params);
        bytes memory payload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CREATE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: parameters
            })
        );

        vm.prank(address(0xBEEF));
        vm.expectRevert(CampaignRemoteManager.NotLaPoste.selector);
        campaignRemoteManager.receiveMessage(10, address(this), payload);

        vm.expectRevert(CampaignRemoteManager.InvalidChainId.selector);
        receiveMessage(10, address(this), payload);

        vm.expectRevert(CampaignRemoteManager.InvalidSender.selector);
        receiveMessage(1, address(this), payload);

        uint256 nextId = votemarket.campaignCount();
        assertEq(nextId, 0);

        wrappedToken.mint(address(campaignRemoteManager), params.totalRewardAmount);
        receiveMessage(1, address(campaignRemoteManager), payload);

        nextId = votemarket.campaignCount();
        assertEq(nextId, 1);

        assertEq(votemarket.getCampaign(0).chainId, params.chainId);
        assertEq(votemarket.getCampaign(0).gauge, params.gauge);
        assertEq(votemarket.getCampaign(0).manager, params.manager);
        assertEq(votemarket.getCampaign(0).rewardToken, address(wrappedToken));
        assertEq(votemarket.getCampaign(0).numberOfPeriods, params.numberOfPeriods);
        assertEq(votemarket.getCampaign(0).maxRewardPerVote, params.maxRewardPerVote);
        assertEq(votemarket.getCampaign(0).totalRewardAmount, params.totalRewardAmount);

        CampaignRemoteManager.CampaignManagementParams memory managementParams = CampaignRemoteManager
            .CampaignManagementParams({
            campaignId: 0,
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            totalRewardAmount: 1000e18,
            maxRewardPerVote: 1000e18
        });

        bytes memory managementParameters = abi.encode(managementParams);
        bytes memory managementPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.MANAGE_CAMPAIGN,
                sender: address(0xCAFE),
                votemarket: address(votemarket),
                parameters: managementParameters
            })
        );

        vm.prank(address(0xBEEF));
        vm.expectRevert(CampaignRemoteManager.NotLaPoste.selector);
        campaignRemoteManager.receiveMessage(10, address(this), managementPayload);

        vm.expectRevert(CampaignRemoteManager.InvalidChainId.selector);
        receiveMessage(10, address(this), managementPayload);

        vm.expectRevert(CampaignRemoteManager.InvalidSender.selector);
        receiveMessage(1, address(this), managementPayload);

        vm.expectRevert(CampaignRemoteManager.InvalidCampaignManager.selector);
        receiveMessage(1, address(campaignRemoteManager), managementPayload);

        managementPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.MANAGE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: managementParameters
            })
        );

        wrappedToken.mint(address(campaignRemoteManager), managementParams.totalRewardAmount);
        receiveMessage(1, address(campaignRemoteManager), managementPayload);

        assertEq(votemarket.getCampaign(0).totalRewardAmount, params.totalRewardAmount);
        uint256 startTime = votemarket.getCampaign(0).startTimestamp;

        assertEq(
            votemarket.getCampaignUpgrade(0, startTime).totalRewardAmount,
            params.totalRewardAmount + managementParams.totalRewardAmount
        );
        assertEq(votemarket.getCampaignUpgrade(0, startTime).maxRewardPerVote, managementParams.maxRewardPerVote);
        assertEq(
            votemarket.getCampaignUpgrade(0, startTime).numberOfPeriods,
            managementParams.numberOfPeriods + params.numberOfPeriods
        );

        assertEq(wrappedToken.balanceOf(address(campaignRemoteManager)), 0);
        assertEq(
            wrappedToken.balanceOf(address(votemarket)), params.totalRewardAmount + managementParams.totalRewardAmount
        );
    }

    function test_receiveMessage_updateManager() public {
        CampaignRemoteManager.CampaignCreationParams memory createParams = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: address(0xBEEF),
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1000e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(0),
            isWhitelist: false
        });

        bytes memory createParameters = abi.encode(createParams);
        bytes memory createPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CREATE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: createParameters
            })
        );

        wrappedToken.mint(address(campaignRemoteManager), createParams.totalRewardAmount);
        receiveMessage(1, address(campaignRemoteManager), createPayload);

        bytes memory updateManagerPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.UPDATE_MANAGER,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: abi.encode(0, address(0xCAFE))
            })
        );

        (,, address manager,,,,,,,,) = votemarket.campaignById(0);

        assertEq(manager, address(this));
        receiveMessage(1, address(campaignRemoteManager), updateManagerPayload);

        (,, manager,,,,,,,,) = votemarket.campaignById(0);
        assertEq(manager, address(0xCAFE));
    }

    function test_receiveMessage_closeCampaign() public {
        // First create a campaign
        CampaignRemoteManager.CampaignCreationParams memory createParams = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: address(0xBEEF),
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1000e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(0),
            isWhitelist: false
        });

        // Create campaign through message receiving
        bytes memory createParameters = abi.encode(createParams);
        bytes memory createPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CREATE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: createParameters
            })
        );

        wrappedToken.mint(address(campaignRemoteManager), createParams.totalRewardAmount);
        receiveMessage(1, address(campaignRemoteManager), createPayload);

        skip(1 weeks); // Skip to start of campaign

        // Skip to the end of the campaign
        // 1 week before the start + 2 weeks for the campaign + 1 week to the end
        skip(4 weeks);

        // We're in the claim deadline period, so it should revert with CAMPAIGN_NOT_ENDED
        CampaignRemoteManager.CampaignClosingParams memory closeParams =
            CampaignRemoteManager.CampaignClosingParams({campaignId: 0});

        bytes memory closeParameters = abi.encode(closeParams);
        bytes memory closePayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CLOSE_CAMPAIGN,
                sender: address(0xCAFE),
                votemarket: address(votemarket),
                parameters: closeParameters
            })
        );

        // Update epochs before closing
        _updateEpochs(0);

        // Skip to the end of the claim deadline
        skip(votemarket.CLAIM_WINDOW_LENGTH());

        // Test with wrong manager first
        closePayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CLOSE_CAMPAIGN,
                sender: address(0xCAFE), // Wrong sender
                votemarket: address(votemarket),
                parameters: closeParameters
            })
        );

        vm.expectRevert(CampaignRemoteManager.InvalidCampaignManager.selector);
        receiveMessage(1, address(campaignRemoteManager), closePayload);

        // Test with correct manager
        closePayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.CLOSE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: closeParameters
            })
        );

        receiveMessage(1, address(campaignRemoteManager), closePayload);

        // Verify campaign is closed by checking if we can manage it (should revert)
        CampaignRemoteManager.CampaignManagementParams memory managementParams = CampaignRemoteManager
            .CampaignManagementParams({
            campaignId: 0,
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            totalRewardAmount: 1000e18,
            maxRewardPerVote: 1000e18
        });

        bytes memory managementParameters = abi.encode(managementParams);
        bytes memory managementPayload = abi.encode(
            CampaignRemoteManager.Payload({
                actionType: CampaignRemoteManager.ActionType.MANAGE_CAMPAIGN,
                sender: address(this),
                votemarket: address(votemarket),
                parameters: managementParameters
            })
        );

        vm.expectRevert(Votemarket.CAMPAIGN_ENDED.selector); // Campaign should be closed and unmanageable
        receiveMessage(1, address(campaignRemoteManager), managementPayload);
    }

    function test_setPlatformWhitelist() public {
        address newPlatform = address(0xBEEF);

        // Non-owner cannot whitelist
        vm.prank(address(0xCAFE));
        vm.expectRevert(Ownable.Unauthorized.selector);
        campaignRemoteManager.setPlatformWhitelist(newPlatform, true);

        // Owner can whitelist
        campaignRemoteManager.setPlatformWhitelist(newPlatform, true);
        assertTrue(campaignRemoteManager.whitelistedPlatforms(newPlatform));

        // Owner can unwhitelist
        campaignRemoteManager.setPlatformWhitelist(newPlatform, false);
        assertFalse(campaignRemoteManager.whitelistedPlatforms(newPlatform));
    }

    function test_CampaignManagement_NotWhitelisted() public {
        address nonWhitelistedPlatform = address(0xBEEF);

        CampaignRemoteManager.CampaignCreationParams memory params = CampaignRemoteManager.CampaignCreationParams({
            chainId: 1,
            gauge: address(0xBEEF),
            manager: address(this),
            rewardToken: address(rewardToken),
            numberOfPeriods: 2,
            maxRewardPerVote: 1000e18,
            totalRewardAmount: 1000e18,
            addresses: new address[](0),
            hook: address(0),
            isWhitelist: false
        });

        vm.chainId(1);
        rewardToken.approve(address(campaignRemoteManager), 1000e18);

        vm.expectRevert(CampaignRemoteManager.PlatformNotWhitelisted.selector);
        campaignRemoteManager.createCampaign(params, 10, 100000, nonWhitelistedPlatform);
    }

    /// Mocked functions

    function _updateEpochs(uint256 campaignId) internal {
        /// Get the campaign.
        uint256 endTimestamp = votemarket.getCampaign(campaignId).endTimestamp;
        uint256 startTimestamp = votemarket.getCampaign(campaignId).startTimestamp;

        for (uint256 i = startTimestamp; i < endTimestamp; i += 1 weeks) {
            votemarket.updateEpoch(campaignId, i, "");

            /// Get the campaign.
            endTimestamp = votemarket.getCampaign(campaignId).endTimestamp;
        }
    }

    function sendMessage(ILaPoste.MessageParams memory params, uint256 additionalGasLimit, address refundAddress)
        external
        payable
    {
        for (uint256 i = 0; i < params.tokens.length; i++) {
            rewardToken.transferFrom(msg.sender, address(0xCAFE), params.tokens[i].amount);
        }
    }

    function receiveMessage(uint256 chainId, address sender, bytes memory payload) public {
        campaignRemoteManager.receiveMessage(chainId, sender, payload);
    }

    function wrappedTokens(address token) external view returns (address) {
        return address(wrappedToken);
    }

    function tokenFactory() external view returns (address) {
        return address(this);
    }
}
