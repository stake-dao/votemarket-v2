// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/auth/Ownable.sol";
import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

/// @notice A module for creating and managing campaigns from L1.
contract CampaignRemoteManager is Ownable {
    using SafeTransferLib for address;

    ////////////////////////////////////////////////////////////////
    /// --- STRUCTS
    ///////////////////////////////////////////////////////////////

    enum ActionType {
        CREATE_CAMPAIGN,
        MANAGE_CAMPAIGN
    }

    struct Payload {
        ActionType actionType;
        address sender;
        bytes parameters;
    }

    struct CampaignCreationParams {
        uint256 chainId;
        address gauge;
        address manager;
        address rewardToken;
        uint8 numberOfPeriods;
        uint256 maxRewardPerVote;
        uint256 totalRewardAmount;
        address[] addresses;
        address hook;
        bool isWhitelist;
    }

    struct CampaignManagementParams {
        uint256 campaignId;
        address rewardToken;
        uint8 numberOfPeriods;
        uint256 totalRewardAmount;
        uint256 maxRewardPerVote;
    }

    ////////////////////////////////////////////////////////////////
    /// --- STATE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The Votemarket address on L2s.
    address public immutable VOTEMARKET;

    /// @notice The token factory address.
    address public immutable TOKEN_FACTORY;

    /// @notice The error thrown when the block hash is sent too soon.
    error TooSoon();

    /// @notice The error thrown when the sender is not the La Poste address.
    error NotLaPoste();

    /// @notice The error thrown when the sender is invalid.
    error InvalidSender();

    /// @notice The error thrown when the chain id is invalid.
    error InvalidChainId();

    /// @notice The error thrown when the reward token is invalid.
    error InvalidRewardToken();

    /// @notice The error thrown when the campaign manager is invalid.
    error InvalidCampaignManager();

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    constructor(address _votemarket, address _laPoste, address _tokenFactory) {
        LA_POSTE = _laPoste;
        VOTEMARKET = _votemarket;
        TOKEN_FACTORY = _tokenFactory;
    }

    /// @notice Creates a campaign on L2.
    /// @param params The campaign creation parameters
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    function createCampaign(
        CampaignCreationParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();

        bytes memory parameters = abi.encode(params);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.CREATE_CAMPAIGN, sender: msg.sender, parameters: parameters}));

        SafeTransferLib.safeTransferFrom({
            token: params.rewardToken,
            from: msg.sender,
            to: address(this),
            amount: params.totalRewardAmount
        });

        SafeTransferLib.safeApprove({token: params.rewardToken, to: TOKEN_FACTORY, amount: params.totalRewardAmount});

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            token: ILaPoste.Token({tokenAddress: params.rewardToken, amount: params.totalRewardAmount}),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);
    }

    /// @notice Manages a campaign on L2.
    /// @param params The campaign management parameters
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    /// @dev This function is the most useful if the campaign manager wants to increase the reward amount. Otherwise,
    /// the manager should directly call the `manageCampaign` function on the Votemarket on L2.
    function manageCampaign(
        CampaignManagementParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();

        bytes memory parameters = abi.encode(params);
        bytes memory payload =
            abi.encode(Payload({actionType: ActionType.MANAGE_CAMPAIGN, sender: msg.sender, parameters: parameters}));

        ILaPoste.Token memory token;

        if (params.totalRewardAmount > 0) {
            token = ILaPoste.Token({tokenAddress: params.rewardToken, amount: params.totalRewardAmount});

            SafeTransferLib.safeTransferFrom({
                token: params.rewardToken,
                from: msg.sender,
                to: address(this),
                amount: params.totalRewardAmount
            });

            SafeTransferLib.safeApprove({token: params.rewardToken, to: TOKEN_FACTORY, amount: params.totalRewardAmount});
        }

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            token: token,
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);
    }

    /// @notice Receives a message from La Poste.
    /// @param chainId The chain id
    /// @param sender The sender address
    /// @param payload The payload
    /// @dev Handle the cases of creating and managing campaigns. It makes sure that the sender is the manager of the
    /// campaign and that the chain id is valid.
    function receiveMessage(uint256 chainId, address sender, bytes calldata payload) external onlyLaPoste {
        if (chainId != 1) revert InvalidChainId();
        if (sender != address(this)) revert InvalidSender();

        Payload memory _payload = abi.decode(payload, (Payload));

        if (_payload.actionType == ActionType.CREATE_CAMPAIGN) {
            CampaignCreationParams memory params = abi.decode(_payload.parameters, (CampaignCreationParams));

            address wrappedToken = ITokenFactory(TOKEN_FACTORY).wrappedTokens(params.rewardToken);

            SafeTransferLib.safeApprove({token: wrappedToken, to: address(VOTEMARKET), amount: params.totalRewardAmount});

            IVotemarket(VOTEMARKET).createCampaign({
                chainId: params.chainId,
                gauge: params.gauge,
                manager: params.manager,
                rewardToken: wrappedToken,
                numberOfPeriods: params.numberOfPeriods,
                maxRewardPerVote: params.maxRewardPerVote,
                totalRewardAmount: params.totalRewardAmount,
                addresses: params.addresses,
                hook: params.hook,
                whitelist: params.isWhitelist
            });
        } else {
            CampaignManagementParams memory params = abi.decode(_payload.parameters, (CampaignManagementParams));
            Campaign memory campaign = IVotemarket(VOTEMARKET).getCampaign(params.campaignId);
            if (campaign.manager != _payload.sender) revert InvalidCampaignManager();

            if (params.totalRewardAmount > 0) {
                address wrappedToken = ITokenFactory(TOKEN_FACTORY).wrappedTokens(params.rewardToken);
                if (campaign.rewardToken != wrappedToken) revert InvalidRewardToken();

                SafeTransferLib.safeApprove({
                    token: wrappedToken,
                    to: address(VOTEMARKET),
                    amount: params.totalRewardAmount
                });
            }

            IVotemarket(VOTEMARKET).manageCampaign(
                params.campaignId, params.numberOfPeriods, params.totalRewardAmount, params.maxRewardPerVote
            );
        }
    }

    /// @notice Recovers ERC20 tokens from the contract.
    /// @param token The token address
    /// @param amount The amount of tokens to recover
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
    }
}