# 🗳️ Votemarket V2 – Integration Guide for Protocols

## Overview

This guide explains how protocols can integrate **Votemarket V2** to automatically create campaigns via smart contract interactions. Votemarket V2 enables protocols to incentivize governance voting through reward campaigns.

## Quick Start

Find all supported protocols, contract addresses, and learn how Votemarket V2 works in our [GitHub repository](https://github.com/stake-dao/votemarket-v2).

## 1. Prerequisites

### 1.1 Find Your Gauge Address

Use our API to find the correct gauge address for creating your campaign:

**API Endpoint**: `https://api-v2.stakedao.org/[protocol]/gauges`

**Examples**:
- Pendle: `https://api-v2.stakedao.org/pendle/gauges`
- Curve: `https://api-v2.stakedao.org/curve/gauges`
- Balancer: `https://api-v2.stakedao.org/balancer/gauges`
- Fxn : `https://api-v2.stakedao.org/fxn/gauges`

### 1.2 Understanding Your Reward Token

Before creating a campaign, determine where your reward token is located:

- **Mainnet token**: Follow [Section 2](#2-creating-campaigns-with-mainnet-tokens)
- **L2 token**: Follow [Section 3](#3-creating-campaigns-with-l2-tokens)

## 2. Creating Campaigns with Mainnet Tokens

Since Votemarket campaigns operate on L2 networks, mainnet tokens require bridging through our **CampaignRemoteManager**.

### 2.1 Token Approval

First, approve the CampaignRemoteManager to spend your tokens on **mainnet**:

```solidity
IERC20(tokenReward).approve(CampaignRemoteManagerAddress, amount);
```

### 2.2 Campaign Creation

Create the campaign and bridge funds simultaneously:

#### Interface

```solidity
struct CampaignCreationParams {
    uint256 chainId;                // Source chain ID (1 for mainnet)
    address gauge;                  // Target gauge address
    address manager;                // Campaign manager address
    address rewardToken;            // Mainnet token address
    uint8 numberOfPeriods;          // Campaign duration in weeks
    uint256 maxRewardPerVote;       // Maximum reward per vote
    uint256 totalRewardAmount;      // Total campaign budget
    address[] addresses;            // Blacklist/whitelist addresses
    address hook;                   // Hook contract address
    bool isWhitelist;              // True for whitelist, false for blacklist
}

interface ICampaignRemoteManager {
    function createCampaign(
        CampaignCreationParams memory params,
        uint256 destinationChainId,
        uint256 additionalGasLimit,
        address votemarket
    ) external payable;
}
```

#### Parameters

| Parameter | Description |
|-----------|-------------|
| `chainId` | Always `1` for mainnet |
| `gauge` | Target gauge address for vote incentivization |
| `manager` | Address authorized to manage the campaign |
| `rewardToken` | Mainnet token contract address |
| `numberOfPeriods` | Campaign duration in weeks |
| `maxRewardPerVote` | Maximum reward amount per individual vote |
| `totalRewardAmount` | Total budget (e.g., 2000 USDC for 2 weeks at 1000 USDC/week) |
| `addresses` | Array of addresses for blacklist/whitelist |
| `hook` | Hook contract address (use zero address for rollover) |
| `isWhitelist` | `true` for whitelist mode, `false` for blacklist mode |
| `destinationChainId` | Target L2 network (must be [supported](https://github.com/stake-dao/votemarket-v2?tab=readme-ov-file#deployment-addresses)) |
| `additionalGasLimit` | Gas limit for cross-chain execution |
| `votemarket` | Votemarket contract address on destination L2 |

#### Chainlink CCIP Fees

Cross-chain messaging requires ETH for Chainlink fees. Calculate the required amount using our [fee calculation service](https://github.com/stake-dao/votemarket-proof-toolkit/blob/main/src/votemarket_toolkit/shared/services/ccip_fee_service.py) and include it as the transaction value.

#### Track Your Transaction

Once your transaction is mined, you can track the bridging execution on the [Chainlink CCIP Explorer](https://ccip.chain.link/). This allows you to monitor the cross-chain message delivery and confirm when your campaign has been successfully created on the destination L2.

## 3. Creating Campaigns with L2 Tokens

For tokens already on L2 networks, create campaigns directly without bridging.

### 3.1 Token Approval

Approve the Votemarket contract on the target L2:

```solidity
IERC20(tokenReward).approve(VotemarketContractAddress, totalRewardAmount);
```

### 3.2 Campaign Creation

#### Interface

```solidity
interface IVotemarket {
    function createCampaign(
        uint256 chainId,
        address gauge,
        address manager,
        address rewardToken,
        uint8 numberOfPeriods,
        uint256 maxRewardPerVote,
        uint256 totalRewardAmount,
        address[] memory addresses,
        address hook,
        bool whitelist
    ) external returns (uint256 campaignId);
}
```

#### Parameters

| Parameter | Description |
|-----------|-------------|
| `chainId` | L2 network chain ID |
| `gauge` | Target gauge address for vote incentivization |
| `manager` | Address authorized to manage the campaign |
| `rewardToken` | L2 token contract address |
| `numberOfPeriods` | Campaign duration in weeks |
| `maxRewardPerVote` | Maximum reward amount per individual vote |
| `totalRewardAmount` | Total campaign budget |
| `addresses` | Array of addresses for blacklist/whitelist |
| `hook` | Hook contract address (use zero address for rollover) |
| `whitelist` | `true` for whitelist mode, `false` for blacklist mode |

## Support

For technical assistance or questions:
- Review the [GitHub repository](https://github.com/stake-dao/votemarket-v2)
- Check contract addresses and supported networks
- Consult the fee calculation toolkit for cross-chain operations
