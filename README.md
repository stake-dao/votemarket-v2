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
| Oracle | `0xEF2BB9DA5834E98bC146C7a94153e9043777E3aC` | Arbitrum, Optimism, Base, Polygon |
| Verifier | `0x2146Ecc11B89bBd08016B708f2DA3eddD52D8F90` | Arbitrum, Optimism, Base, Polygon |
| OracleLens | `0x2F3b9dbf87ee2B8b6b19eDd634487427B31E500d` | Arbitrum, Optimism, Base, Polygon |
| Votemarket | `0xa866BE05309CF8F5d4402b0822Fc80F14ECFC603` | Arbitrum, Optimism, Base, Polygon |

#### Periphary

| Contract | Address | Networks |
|----------|---------|----------|
| Bundler | `0x0000000000000000000000000000000000000000` | Arbitrum, Optimism, Base, Polygon |
| L1Sender | `0x0000000000000000000000000000000000000000` | Mainnet |
| L1BlockOracleUpdater | `0x0000000000000000000000000000000000000000` | Arbitrum, Optimism, Base, Polygon |
| CampaignRemoteManager | `0x0000000000000000000000000000000000000000` | Mainnet, Arbitrum, Optimism, Base, Polygon |

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
