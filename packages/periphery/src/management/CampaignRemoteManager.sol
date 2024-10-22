// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@solady/src/utils/SafeTransferLib.sol";
import "@votemarket/src/interfaces/IVotemarket.sol";

import "src/interfaces/ILaPoste.sol";
import "src/interfaces/ITokenFactory.sol";

/// @notice A module for sending the block hash to the L1 block oracle updater.
contract CampaignRemoteManager {
    using SafeTransferLib for address;

    enum ActionType {
        CREATE_CAMPAIGN,
        MANAGE_CAMPAIGN
    }

    struct Payload {
        ActionType actionType;
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
        uint8 numberOfPeriods;
        uint256 totalRewardAmount;
        uint256 maxRewardPerVote;
    }

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

    /// @notice The error thrown when the chain id is invalid.
    error InvalidChainId();

    modifier onlyLaPoste() {
        if (msg.sender != LA_POSTE) revert NotLaPoste();
        _;
    }

    constructor(address _votemarket, address _laPoste, address _tokenFactory) {
        LA_POSTE = _laPoste;
        VOTEMARKET = _votemarket;
        TOKEN_FACTORY = _tokenFactory;
    }

    /// @notice Sends the block hash to the L1 block oracle updater.
    function createCampaign(
        CampaignCreationParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit
    ) external payable {
        bytes memory parameters = abi.encode(params);
        bytes memory payload = abi.encode(Payload({actionType: ActionType.CREATE_CAMPAIGN, parameters: parameters}));

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

    function receiveMessage(uint256, address, bytes calldata payload) external onlyLaPoste {

        Payload memory _payload = abi.decode(payload, (Payload));

        if (_payload.actionType == ActionType.CREATE_CAMPAIGN) {
            CampaignCreationParams memory params = abi.decode(_payload.parameters, (CampaignCreationParams));
        } else {
            CampaignManagementParams memory params = abi.decode(_payload.parameters, (CampaignManagementParams));
        }
    }
}
