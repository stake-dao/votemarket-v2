# Specs

(WIP)

## Votemarket
* Multicallable to batch multiple actions.
* Ownable with a two step ownership transfer.
* Reads data from Oracle contract to distribute rewards.

## Oracle
* Reads data from Warehouse contract.
* Provide standardized data to Votemarket.

## Verifiers
* Using RLP Verifier to verify the data and insert it into the Warehouse contract.

## Warehouse
* Stores state root hashes per epoch.
* Stores the data from the verifiers.

## Bundler
* Helper contract to bundle inserts into the Warehouse contract and distribute rewards.