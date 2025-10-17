### DepositHelper

## Presentation

The contract `DepositHelper` is a management tool to create multiple Votemarket campaigns for different gauges.

## Roles

| **Role**            | **Description**                                                                                                             | **Accessible Functions**                                                                                                                                                |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Owner**           | Main administrator of the contract. Has full control over security-sensitive settings, key addresses, and fund withdrawals. | `setManager`, `setRewardToken`, `setRewardNotifier`, `setCampaignRemoteManager`, `setVotemarket`, `addApprovedGauge`, `removeApprovedGauge`, `execute`, `withdrawEther` |
| **Manager**         | Operational role responsible for configuring campaign parameters such as weights, gas settings, hooks, and exclusion lists. | `setWeights`, `setExcludeAddresses`, `setHook`, `setGasSettings`, `setMaxRewardPerVote`                                                                                 |
| **Reward Notifier** | Authorized entity allowed to notify and transfer rewards, triggering campaign creation.             | `notifyReward`                                                                                                                                                          |

## Usage

**1. Initial config**

```
constructor(
        address _rewardToken,
        address _rewardNotifier,
        address _owner,
        address _campaignRemoteManager,
        address _votemarket,
        uint256 _maxRewardPerVote
    )
```

`_rewardToken`: Address of the reward token.

`_rewardNotifier`: Address of the entity distributing the `_rewardToken` and initiating the campaigns creations.

`_owner`: Address of the owner of the contract.

`_campaignRemoteManager`: Address of the utilityContract allowing to initiate the campaign from mainnet to the destination chain (current: `0x53aD4Cd1F1e52DD02aa9FC4A8250A1b74F351CA2`)

`_votemarket`: Address of the votemarket platform on the destination chain (current: `0x8c2c5A295450DDFf4CB360cA73FCCC12243D14D9`)

`_maxRewardPerVote`: Maximum amount of `_rewardToken` to be spent for a veCRV vote (to be adjusted with market prices of `_rewardToken` and associated directed inflation of the veCRV vote)

**2. Owner management**

- Add/remove approved gauges, that the `manager` will be able to set weights for.
```
addApprovedGauge(address gauge);
removeApprovedGauge(address gauge);
```

- Set roles and contracts
```
setManager(address _manager);
setCampaignRemoteManager(address remoteManager);
setVotemarket(address voteMarket);
setRewardToken(address token);
setRewardNotifier(address notifier);
```

- Withdraw Ether and custom execute functions
```
withdrawEther(uint256 amount, address payable to);
execute(address to, uint256 value, bytes calldata data);
```

**3. Manager guide**

- Define the gauges to vote for and the split of rewards between campaigns.
```
setWeights(address[] gauges, uint16[] weights);
```
All gauges in the list must be **approved by the owner**, and the **sum of all weights must equal 10,000** (representing 100.00%).
The `gauges` and `weights` arrays must have the same length, where each index corresponds directly — meaning the first gauge in the list is associated with the first weight, the second with the second, and so on.

⚠️ All `gauges` addresses **must be added in ascending order** to prevent duplicates.


- Define the excluded addresses for the campaign.
```
setExcludeAddresses(address[] memory excluded);
```
All the addresses in the `excluded` list will not receive rewards if they vote for the gauges. Limited to 50 addresses.

⚠️ All `excluded` addresses **must be added in ascending order** to prevent duplicates.

- Adjust campaign parameters 
```
setHook(address hook);
setMaxRewardPerVote(uint256 newLimit);
```
The `hook` is the fallback contract managing the leftovers of rewards. Leaving hook to zero address will make the leftovers rollover to te following period. You can also set a hook to refund unspent rewards on the destination chain to the manager with the address: `0x7a3830C1383312985cc2256F22ba6a0ce25c4304`.

The `maxRewardPerVote` is the maximum amount of `_rewardToken` to be spent for a veCRV vote. It should be adjusted according to the market price of `_rewardToken` and the expected veCRV-directed inflation rate before campaign creation, to ensure optimal reward efficiency and prevent overspending.

- Adjust gas settings
```
setGasSettings(uint256 campaignCreationGas, uint256 blacklistedAddressGas, uint256 gasPrice);
```

Defines the gas configuration used for cross-chain campaign creation:

`campaignCreationGas`: the base gas required to create a campaign on the destination chain.

`blacklistedAddressGas`: the additional gas cost per excluded (blacklisted) address.

`gasPrice`: the gas price (in wei) used for transactions on the destination chain.

⚠️ Important:
The contract itself pays the required **Ether fees** for cross-chain campaign creation.
**Make sure it always holds enough ETH to cover the gas costs** - otherwise, campaign creation transactions will fail.

