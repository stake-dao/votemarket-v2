# VoteMarket Data

This folder contains the data for the VoteMarket.

## Data Files

- [`votemarkets.json`](./votemarkets.json): Contains the list of all the votemarkets deployed on each chain.

## Data Format

- [`votemarkets.json`](./votemarkets.json):

```jsonc
{
  "count": 103,
  "data": [
    {
      "protocol": "CURVE", // CURVE || BALANCER || FXN
      "chainId": 42161, // 10 || 8453 || 137 || 100
      "platform": "0x155a7Cf21F8853c135BdeBa27FEA19674C65F2b4", // The address of the votemarket contract
      "seed": "0x1234567890abcdef" // The seed used to deploy the protocol
    }
  ]
}
```

## Scripts

### Update the `votemarkets.json` file

This script updates the `votemarkets.json` by adding new deployments to the database.
This script is **not intended to be called manually**. It is automatically called when the `Deploy.s.sol` script is executed in broadcast mode.

#### Usage

```bash
node data/update-votemarket.js <protocol> <platform> <chainIds> <seed>
```

- `protocol`: The protocol of the votemarket.
- `platform`: The platform of the votemarket.
- `chainIds`: The chain IDs of the votemarket.
- `seed`: The seed used to deploy the protocol.

#### Example:

```bash
node data/update-votemarket.js CURVE 0x155a7Cf21F8853c135BdeBa27FEA19674C65F2b4 "[10,8453,137,100]" 0x1234567890abcdef
```
