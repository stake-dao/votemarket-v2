# Votemarket V2

V2 is an evolution of the [Votemarket](https://github.com/stake-dao/votemarket) contract. It's been running for a while at Votemarket at [Etherscan](https://etherscan.io/address/0x0000000895cB182E6f983eb4D8b4E0Aa0B31Ae4c#code).
It is built on top of the [Curve Gauge Controller](https://github.com/curvefi/curve-dao-contracts/blob/master/contracts/GaugeController.vy) contract, and its forks (Balancer, FXN, etc.).

Project creates incentive campaigns for liquidity providers to vote on gauge weights. Contract fetch each period account votes and total votes from the Gauge Controller contract and distributes the rewards accordingly to the voters.

The constraints of the V1 are:

* Gauge Controller doesn't track historical data, so the voter needs to claim the rewards every week. It can be quite expensive.
* Available only on Mainnet. Curve is deployed on many L2s, Projects that doesn't have their token on L1 can't use it.
* The unclaimed rewards are rollovered to the next epoch. While this is a good feature, some projects wants more control over the campaigns on their spending.

V2 is an improvement of the V1 with the following improvements:

* The contract is deployed on L2.
* Data are populated on L2 on an Oracle contract using Storage Proofs.
* Account can bring their proofs to the contract to claim the rewards for any epoch.
* Hooks. Projects can add custom logic to the contract to handle the rollovers.

Architecture is modular. Each component is independent and can be replaced with a different implementation.

Test coverage is 100%.

## Getting Started

This project is a monorepo managed by [pnpm](https://pnpm.io/). Each package is in its own directory.

### Prerequisites

Before you begin, ensure you have met the following requirements:

* pnpm installed
* [Foundry](https://book.getfoundry.sh/getting-started/installation.html) installed
* Python 3.7 or higher installed
* [pip](https://pip.pypa.io/en/stable/installation/) (Python package installer) installed

### Installation

1. Clone the repository:

```sh
git clone https://github.com/stake-dao/votemarket-v2.git
```

2. Install the dependencies:

```sh
cd votemarket-v2/packages/votemarket
pip install web3 rlp eth_abi python-dotenv
make install
```

3. Compile the contracts:

```sh
make
```

4. Run the tests:

```sh
make test
```