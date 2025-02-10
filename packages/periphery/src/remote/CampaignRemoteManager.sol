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
        MANAGE_CAMPAIGN,
        CLOSE_CAMPAIGN,
        UPDATE_MANAGER
    }

    struct Payload {
        ActionType actionType;
        address sender;
        address votemarket;
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

    struct CampaignClosingParams {
        uint256 campaignId;
    }

    ////////////////////////////////////////////////////////////////
    /// --- STATE VARIABLES
    ///////////////////////////////////////////////////////////////

    /// @notice The La Poste address.
    address public immutable LA_POSTE;

    /// @notice The token factory address.
    address public immutable TOKEN_FACTORY;

    /// @notice Mapping of whitelisted votemarket platforms
    mapping(address => bool) public whitelistedPlatforms;

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

    /// @notice The error thrown when the action type is invalid.
    error InvalidActionType();

    /// @notice The error thrown when the platform is not whitelisted
    error PlatformNotWhitelisted();

    /// @notice The event emitted when a campaign creation payload is sent.
    event CampaignCreationPayloadSent(CampaignCreationParams indexed params);

    /// @notice The event emitted when a campaign management payload is sent.
    event CampaignManagementPayloadSent(CampaignManagementParams indexed params);

    /// @notice The event emitted when a campaign closing payload is sent.
    event CampaignClosingPayloadSent(CampaignClosingParams indexed params);

    /// @notice The event emitted when a campaign update manager payload is sent.
    event CampaignUpdateManagerPayloadSent(address indexed sender, uint256 indexed campaignId, address indexed newManager);

    /// @notice Event emitted when a platform is whitelisted/unwhitelisted
    event PlatformWhitelistUpdated(address indexed platform, bool whitelisted);

    ////////////////////////////////////////////////////////////////
    /// --- MODIFIERS
    ///////////////////////////////////////////////////////////////

    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    constructor(address _laPoste, address _tokenFactory, address _owner) {
        LA_POSTE = _laPoste;
        TOKEN_FACTORY = _tokenFactory;

        _initializeOwner(_owner);
    }

    /// @notice Creates a campaign on L2.
    /// @param params The campaign creation parameters
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    /// @param votemarket The Votemarket address on L2
    function createCampaign(
        CampaignCreationParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();
        if (!whitelistedPlatforms[votemarket]) revert PlatformNotWhitelisted();

        bytes memory parameters = abi.encode(params);
        bytes memory payload = abi.encode(
            Payload({
                actionType: ActionType.CREATE_CAMPAIGN,
                sender: msg.sender,
                votemarket: votemarket,
                parameters: parameters
            })
        );

        SafeTransferLib.safeTransferFrom({
            token: params.rewardToken,
            from: msg.sender,
            to: address(this),
            amount: params.totalRewardAmount
        });

        SafeTransferLib.safeApprove({token: params.rewardToken, to: TOKEN_FACTORY, amount: params.totalRewardAmount});

        ILaPoste.Token[] memory tokens = new ILaPoste.Token[](1);
        tokens[0] = ILaPoste.Token({tokenAddress: params.rewardToken, amount: params.totalRewardAmount});

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            tokens: tokens,
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);

        emit CampaignCreationPayloadSent(params);
    }

    /// @notice Manages a campaign on L2.
    /// @param params The campaign management parameters
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    /// @param votemarket The Votemarket address on L2
    /// @dev This function is the most useful if the campaign manager wants to increase the reward amount. Otherwise,
    /// the manager should directly call the `manageCampaign` function on the Votemarket on L2.
    function manageCampaign(
        CampaignManagementParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();
        if (!whitelistedPlatforms[votemarket]) revert PlatformNotWhitelisted();

        bytes memory parameters = abi.encode(params);
        bytes memory payload = abi.encode(
            Payload({
                actionType: ActionType.MANAGE_CAMPAIGN,
                sender: msg.sender,
                votemarket: votemarket,
                parameters: parameters
            })
        );

        ILaPoste.Token[] memory tokens;

        if (params.totalRewardAmount > 0) {
            tokens = new ILaPoste.Token[](1);
            tokens[0] = ILaPoste.Token({tokenAddress: params.rewardToken, amount: params.totalRewardAmount});

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
            tokens: tokens,
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);

        emit CampaignManagementPayloadSent(params);
    }

    /// @notice Updates the manager for a campaign on L2.
    /// @param campaignId The campaign id
    /// @param newManager The new manager address
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    /// @param votemarket The Votemarket address on L2
    function updateManager(
        uint256 campaignId,
        address newManager,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();
        if (!whitelistedPlatforms[votemarket]) revert PlatformNotWhitelisted();

        bytes memory parameters = abi.encode(campaignId, newManager);
        bytes memory payload = abi.encode(
            Payload({
                actionType: ActionType.UPDATE_MANAGER,
                sender: msg.sender,
                votemarket: votemarket,
                parameters: parameters
            })
        );

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            tokens: new ILaPoste.Token[](0),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);

        emit CampaignUpdateManagerPayloadSent(msg.sender, campaignId, newManager);
    }

    /// @notice Closes a campaign on L2.
    /// @param params The campaign closing parameters
    /// @param destinationChainId The destination chain id
    /// @param additionalGasLimit The additional gas limit
    /// @param votemarket The Votemarket address on L2
    function closeCampaign(
        CampaignClosingParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable {
        if (block.chainid != 1) revert InvalidChainId();
        if (!whitelistedPlatforms[votemarket]) revert PlatformNotWhitelisted();

        bytes memory parameters = abi.encode(params);
        bytes memory payload = abi.encode(
            Payload({
                actionType: ActionType.CLOSE_CAMPAIGN,
                sender: msg.sender,
                votemarket: votemarket,
                parameters: parameters
            })
        );

        ILaPoste.MessageParams memory messageParams = ILaPoste.MessageParams({
            destinationChainId: destinationChainId,
            to: address(this),
            tokens: new ILaPoste.Token[](0),
            payload: payload
        });

        ILaPoste(LA_POSTE).sendMessage{value: msg.value}(messageParams, additionalGasLimit, msg.sender);

        emit CampaignClosingPayloadSent(params);
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

            SafeTransferLib.safeApprove({token: wrappedToken, to: _payload.votemarket, amount: params.totalRewardAmount});

            IVotemarket(_payload.votemarket).createCampaign({
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
        } else if (_payload.actionType == ActionType.MANAGE_CAMPAIGN) {
            CampaignManagementParams memory params = abi.decode(_payload.parameters, (CampaignManagementParams));
            Campaign memory campaign = IVotemarket(_payload.votemarket).getCampaign(params.campaignId);
            if (campaign.manager != _payload.sender) revert InvalidCampaignManager();

            if (params.totalRewardAmount > 0) {
                address wrappedToken = ITokenFactory(TOKEN_FACTORY).wrappedTokens(params.rewardToken);
                if (campaign.rewardToken != wrappedToken) revert InvalidRewardToken();

                SafeTransferLib.safeApprove({
                    token: wrappedToken,
                    to: _payload.votemarket,
                    amount: params.totalRewardAmount
                });
            }

            IVotemarket(_payload.votemarket).manageCampaign(
                params.campaignId, params.numberOfPeriods, params.totalRewardAmount, params.maxRewardPerVote
            );
        } else if (_payload.actionType == ActionType.CLOSE_CAMPAIGN) {
            CampaignClosingParams memory params = abi.decode(_payload.parameters, (CampaignClosingParams));
            Campaign memory campaign = IVotemarket(_payload.votemarket).getCampaign(params.campaignId);
            if (campaign.manager != _payload.sender) revert InvalidCampaignManager();

            IVotemarket(_payload.votemarket).closeCampaign(params.campaignId);
        } else if (_payload.actionType == ActionType.UPDATE_MANAGER) {
            (uint256 campaignId, address newManager) = abi.decode(_payload.parameters, (uint256, address));
            Campaign memory campaign = IVotemarket(_payload.votemarket).getCampaign(campaignId);
            if (campaign.manager != _payload.sender) revert InvalidCampaignManager();

            IVotemarket(_payload.votemarket).updateManager(campaignId, newManager);
        } else {
            revert InvalidActionType();
        }
    }

    /// @notice Recovers ERC20 tokens from the contract.
    /// @param token The token address
    /// @param amount The amount of tokens to recover
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
    }

    /// @notice Whitelist or unwhitelist a platform
    /// @param platform The platform address to whitelist/unwhitelist
    /// @param whitelisted The whitelist status
    function setPlatformWhitelist(address platform, bool whitelisted) external onlyOwner {
        whitelistedPlatforms[platform] = whitelisted;
        emit PlatformWhitelistUpdated(platform, whitelisted);
    }
}
