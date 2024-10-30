# Votemarket V2

## Overview

Votemarket V2 is an advanced evolution of the original [Votemarket](https://github.com/stake-dao/votemarket) protocol, designed to create and manage incentive campaigns for liquidity providers voting on gauge weights. The system is built on top of the [Curve Gauge Controller](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/GaugeController.vy) contract and its forks (Balancer, FXN, etc.).

[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL1.1-blue.svg)](https://github.com/stake-dao/votemarket-v2/blob/main/LICENSE)

## Key Features

- 100% permissionless
- Layer 2 deployment support
- Oracle-based data population using Storage Proofs
- Historical epoch reward claims
- Customizable campaign management through hooks
- Cross-chain compatibility
- Modular architecture for component replacement

## Improvements Over V1

| Feature | V1 | V2 |
|---------|----|----|
| Chain Support | Mainnet only | Multi-chain (L1 + L2s) |
| Reward Claims | Weekly requirement | Flexible timing |
| Campaign Control | Fixed rollover | Customizable via hooks |
| Cost Efficiency | Higher gas costs | Optimized for L2 |

## System Architecture

### Component Overview

The system consists of three main components:

1. **Block Management System**
   - L1Sender: Broadcasts block information
   - LaPoste: CCIP-compatible message bus
   - L1BlockOracleUpdater: Updates Oracle with block data

2. **Campaign Management**
   - CampaignRemoteManager (L1)
   - CampaignRemoteManager (L2)
   - Votemarket Contract

3. **Oracle System**
   - Storage Proofs verification
   - Cross-chain data synchronization

### Architecture Diagrams

#### L1 Block Broadcasting
```mermaid
graph LR
    L1Sender -->|broadcastBlock| LaPoste
    LaPoste -->|sendMessage| CCIP
```

#### L2 Block Processing
```mermaid
graph LR
    CCIP -->|receiveMessage| LaPoste
    LaPoste -->|receiveMessage| L1BlockOracleUpdater
    L1BlockOracleUpdater -->|insertBlockNumber| Oracle
```

### Deployment Addresses

#### Core

| Contract | Address | Networks |
|----------|---------|----------|
| Oracle | `0x36F5B50D70df3D3E1c7E1BAf06c32119408Ef7D8` | Arbitrum, Optimism, Base, Polygon |
| Verifier | `0x2Fa15A44eC5737077a747ed93e4eBD5b4960a465` | Arbitrum, Optimism, Base, Polygon |
| OracleLens | `0x99EDB5782da5D799dd16a037FDbc00a1494b9Ead` | Arbitrum, Optimism, Base, Polygon |
| Votemarket | `0x5e5C922a5Eeab508486eB906ebE7bDFFB05D81e5` | Arbitrum, Optimism, Base, Polygon |

#### Periphary

| Contract | Address | Networks |
|----------|---------|----------|
| Bundler | `0xc86b4c2c39ad2D4CC5d9632bDCD6f23338d371F9` | Arbitrum, Optimism, Base, Polygon |
| L1Sender | `0xd81956723f351df8e75548fF005ce5Ba47238587` | Mainnet |
| L1BlockOracleUpdater | `0xb104D3A146F909D9D722005A5BDb17E570C88C6A` | Arbitrum, Optimism, Base, Polygon |
| CampaignRemoteManager | `0x17048e90A8e10ba20FC0e242ba01c2039D9511D1` | Mainnet, Arbitrum, Optimism, Base, Polygon |

## Getting Started

### Prerequisites

- [pnpm](https://pnpm.io/) (v8.0.0 or higher)
- [Foundry](https://book.getfoundry.sh/getting-started/installation.html)
- Python 3.7+
- [pip](https://pip.pypa.io/en/stable/installation/)

### Environment Setup

1. Clone the repository:
```bash
git clone https://github.com/stake-dao/votemarket-v2.git
cd votemarket-v2
```

2. Install dependencies:
```bash
cd packages/votemarket
pip install -r requirements.txt
make install
```

3. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

### Build and Test

```bash
# Compile contracts
make

# Run tests
make test

# Generate coverage report
make coverage
```

## Security

### Audits

- [Trust Security](https://docs.stakedao.org/audits)

### Known Limitations

1. Campaign Manager Control
   - Campaign Managers have significant control over campaigns
   - Potential for campaign manipulation ("rug") exists

2. Proof Verification Costs
   - Multiple proof verifications can be gas-intensive
   - Future optimizations planned through ZK Verifiers (Succinct SP1)

### Bug Bounty
Visit our [Bug Bounty Program](https://docs.stakedao.org/bug-bounty) for details on reporting security issues.

## Documentation

- [LaPoste Integration](https://github.com/stake-dao/laposte)

## Support

- [Discord Community](https://discord.com/invite/qwQfw4kmYy)
- [Forum](https://gov.stakedao.org/)

## License

This project is licensed under the [BUSL 1.1](LICENSE) - see the [LICENSE](LICENSE) file for details.

## References

- [LaPoste Repository](https://github.com/stake-dao/laposte)
- [Curve Gauge Controller](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/GaugeController.vy)

## Acknowledgments

- All contributors and auditors
