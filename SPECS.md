# Specs

## Votemarket

### Votemarket
* Multicallable to batch multiple actions.
* Ownable with a two step ownership transfer.
* Reads data from Oracle contract to distribute rewards.

### OracleProxy
* Reads data from Oracle contract.
* Provide standardized data to Votemarket.

### Oracle
* Stores state root hashes per epoch.
* Stores the data from the verifiers.

### Verifiers
* Using RLP Verifier to verify the data and insert it into the Warehouse contract.

### Bundler
* Helper contract to bundle inserts into the Warehouse contract and distribute rewards.


## Pigeon (Cross-chain Messaging Aggregator)

### La Poste
* Cross-chain message aggregator.
* Standard Interface for sending messages.

### Token Factory
* 