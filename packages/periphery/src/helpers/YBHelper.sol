// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.25;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface CampaignRemoteManager {
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
    function createCampaign(
        CampaignCreationParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable;
}

contract DepositHelper {
    using SafeERC20 for IERC20;

    uint256 public constant DESTINATION_CHAIN_ID = 42161;
    address public immutable owner;
    address public hook;
    address public manager;
    address public votemarket;
    address public rewardToken;
    address public rewardNotifier;
    address public campaignRemoteManager;
    uint256 public maxRewardPerVote;

    struct GasSettings {
        uint256 campaignCreationGas;
        uint256 blacklistedAddressGas;
        uint256 gasPrice;
    }

    GasSettings public gasSettings;

    struct CurrentWeights {
        address[] gauges;
        uint16[] weights;
    }

    CurrentWeights private currentWeights; // cannot publicly return struct arrays
    mapping(address => bool) public isApprovedGauge; // gauge => isApproved
    uint16 public constant MAX_GAUGE_WEIGHT = 10000;

    address[] public excludeAddresses; // addresses to exclude from eligibility for rewards

    constructor(
        address _rewardToken,
        address _rewardNotifier,
        address _owner,
        address _campaignRemoteManager,
        address _votemarket,
        uint256 _maxRewardPerVote
    ) {
        manager = msg.sender;
        owner = _owner;
        rewardNotifier = _rewardNotifier;
        rewardToken = _rewardToken;
        campaignRemoteManager = _campaignRemoteManager;
        votemarket = _votemarket;
        maxRewardPerVote = _maxRewardPerVote == 0 ? type(uint256).max : maxRewardPerVote;

        // Setting default destination chain gas settings
        gasSettings.campaignCreationGas = 600_000;
        gasSettings.blacklistedAddressGas = 50_000;
        gasSettings.gasPrice = 0.01 gwei;
        IERC20(rewardToken).approve(campaignRemoteManager, type(uint256).max);
    }

    // --- Errors ---

    /// @notice Error thrown when the caller doesn't have the right to execute the function
    error UNAUTHORIZED();

    /// @notice Error thrown when one or many parameters are invalid
    error INVALID_PARAMETER();

    /// @notice Error thrown if no weight is set for gauges
    error NO_WEIGHTS();

    /// @notice Error thrown when a gauge has weights and shouldn't for the following action
    error HAS_WEIGHT();

    /// @notice Error thrown when the execute call fails
    error EXECUTION_FAILED();

    /// @notice Error thrown when the contract doesn't own enough Ether to create the campaigns
    error NOT_ENOUGH_GAS();

    // --- Modifiers ---

    modifier onlyManager() {
        _onlyManager();
        _;
    }
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }
    modifier onlyRewardNotifier() {
        _onlyRewardsNotifier();
        _;
    }

    // --- View functions ---

    function getCurrentWeights() external view returns (address[] memory, uint16[] memory) {
        return (currentWeights.gauges, currentWeights.weights);
    }

    function currentWeightOfGauge(address _gauge) public view returns (uint16) {
        for (uint256 i = 0; i < currentWeights.gauges.length; i++) {
            if (currentWeights.gauges[i] == _gauge) {
                return currentWeights.weights[i];
            }
        }
        return 0;
    }

    // --- Main function ---

    function notifyReward(uint256 _amount) external onlyRewardNotifier {
        if (currentWeights.gauges.length == 0) revert NO_WEIGHTS();
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 currentEpoch = block.timestamp / 1 weeks * 1 weeks;
        uint256 additionalGasLimit =
            gasSettings.campaignCreationGas + gasSettings.blacklistedAddressGas * excludeAddresses.length;

        // Check contract balance
        if (address(this).balance < currentWeights.gauges.length * additionalGasLimit * gasSettings.gasPrice) {
            revert NOT_ENOUGH_GAS();
        }

        // Create campaigns according to weights
        uint256 assignedAmount = 0;
        for (uint256 i = 0; i < currentWeights.weights.length; i++) {
            // Avoid rounding dusts by assigning all the reminding amount to the last gauge
            uint256 amount = (i == currentWeights.weights.length - 1)
                ? _amount - assignedAmount
                : (_amount * currentWeights.weights[i]) / MAX_GAUGE_WEIGHT;

            CampaignRemoteManager.CampaignCreationParams memory params = CampaignRemoteManager.CampaignCreationParams({
                chainId: block.chainid,
                gauge: currentWeights.gauges[i],
                manager: manager, // manager or owner ?
                rewardToken: rewardToken,
                numberOfPeriods: 2,
                maxRewardPerVote: maxRewardPerVote,
                totalRewardAmount: amount,
                addresses: excludeAddresses,
                hook: hook,
                isWhitelist: false
            });

            CampaignRemoteManager(campaignRemoteManager)
            .createCampaign{
                value: additionalGasLimit * gasSettings.gasPrice
            }(params, DESTINATION_CHAIN_ID, additionalGasLimit, votemarket);

            emit DepositForGauge(currentWeights.gauges[i], amount, currentEpoch);
            assignedAmount += amount;
        }
    }

    // --- Owner functions ---

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
        emit NewManager(_manager);
    }

    function setRewardToken(address _rewardToken) external onlyOwner {
        // remove previous approval
        IERC20(rewardToken).approve(campaignRemoteManager, 0);
        // set new token and approve
        rewardToken = _rewardToken;
        IERC20(rewardToken).approve(campaignRemoteManager, type(uint256).max);
        emit NewRewardToken(_rewardToken);
    }

    function setRewardNotifier(address _rewardNotifier) external onlyOwner {
        rewardNotifier = _rewardNotifier;
        emit NewRewardNotifier(_rewardNotifier);
    }

    function setCampaignRemoteManager(address _campaignRemoteManager) external onlyOwner {
        campaignRemoteManager = _campaignRemoteManager;
        emit NewCampaignRemoteManager(_campaignRemoteManager);
    }

    function setVotemarket(address _votemarket) external onlyOwner {
        votemarket = _votemarket;
        emit NewVotemarket(_votemarket);
    }

    function setMaxRewardPerVote(uint256 _maxRewardPerVote) external onlyOwner {
        maxRewardPerVote = _maxRewardPerVote;
        emit NewMaxRewardPerVote(_maxRewardPerVote);
    }

    function setHook(address _hook) external onlyOwner {
        hook = _hook;
        emit NewHook(_hook);
    }

    function addApprovedGauge(address _gauge) external onlyOwner {
        isApprovedGauge[_gauge] = true;
        emit AddedGauge(_gauge);
    }

    function setGasSettings(uint256 _campaignCreationGas, uint256 _blacklistedAddressGas, uint256 _gasPrice)
        external
        onlyOwner
    {
        if (_campaignCreationGas == 0 || _blacklistedAddressGas == 0 || _gasPrice == 0) {
            revert INVALID_PARAMETER();
        }
        gasSettings.campaignCreationGas = _campaignCreationGas;
        gasSettings.blacklistedAddressGas = _blacklistedAddressGas;
        gasSettings.gasPrice = _gasPrice;
        emit UpdatedGasSettings(_campaignCreationGas, _blacklistedAddressGas, _gasPrice);
    }

    function removeApprovedGauge(address _gauge) external onlyOwner {
        if (currentWeightOfGauge(_gauge) != 0) revert HAS_WEIGHT();
        isApprovedGauge[_gauge] = false;
        emit RemovedGauge(_gauge);
    }

    function execute(address to, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        (bool success, bytes memory result) = to.call{value: value}(data);
        if (!success) revert EXECUTION_FAILED();
        return result;
    }

    function withdrawEther(uint256 amount, address payable to) external onlyOwner {
        if (amount == 0 || to == address(0)) revert INVALID_PARAMETER();
        (bool sent,) = to.call{value: amount}("");
        if (!sent) revert EXECUTION_FAILED();
        emit EtherWithdrawn(to, amount);
    }

    // --- Receive / Fallback ---

    /// @notice Receive plain ETH transfers (no data)
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice Fallback to accept ETH transfers with data or unknown function calls
    fallback() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    // --- Internal functions ---

    /// @notice Internal function to check authorization
    function _onlyManager() internal view {
        if (msg.sender != manager && msg.sender != owner) revert UNAUTHORIZED();
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert UNAUTHORIZED();
    }

    function _onlyRewardsNotifier() internal view {
        if (msg.sender != rewardNotifier && msg.sender != owner) revert UNAUTHORIZED();
    }

    // --- Events ---
    event Notified(address token, uint256 amount);
    event AddedGauge(address indexed gauge);
    event RemovedGauge(address indexed gauge);
    event UpdatedWeights(address[] gauges, uint16[] weights);
    event EtherWithdrawn(address indexed to, uint256 amount);
    event EtherReceived(address indexed from, uint256 amount);
    event NewHook(address hook);
    event NewManager(address manager);
    event NewVotemarket(address votemarket);
    event NewRewardToken(address rewardToken);
    event NewRewardNotifier(address rewardNotifier);
    event UpdatedExclusions(address[] excludeAddresses);
    event NewMaxRewardPerVote(uint256 maxRewardPerVote);
    event NewCampaignRemoteManager(address campaignRemoteManager);
    event UpdatedGasSettings(uint256 campaignCreationGas, uint256 blacklistedAddressGas, uint256 gasPrice);
    event DepositForGauge(address indexed gauge, uint256 amount, uint256 indexed round);
}
