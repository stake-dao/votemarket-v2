# Mock Data

[https://docs.tenderly.co/virtual-testnets/smart-contract-frameworks/foundry](https://docs.tenderly.co/virtual-testnets/smart-contract-frameworks/foundry)


## Scenarios

### Claim scenarios

- Campaign with rewards
- User has voted

#### Scenario 1

- No block data has been bridged

#### Scenario 2

- Block data has been bridged
- User has to bridge his end of lock

#### Scenario 3

- Block data has been bridged
- User has bridged his end of lock

#### Scenario 4

- Block data has been bridged
- User had bridged his end of lock, but increased it

#### Scenario 5

- User already claimed rewards

### Blacklist/Whitelist scenarios

- Campaign with rewards
- User has voted
- Campaign has addresses set as whitelist or blacklist

#### Scenario 6

- Addresses is blacklist
- User is blacklisted

#### Scenario 7

- Addresses is blacklist
- User is not blacklisted

#### Scenario 8

- Addresses is whitelist
- User is whitelisted

#### Scenario 9

- Addresses is whitelist
- User is not whitelisted

### Upgrade scenarios

- Campaign with rewards
- Manager queues an upgrade

#### Scenario 11

- User claims rewards (Upgrade is applied)

#### Scenario 12

- No one has claimed rewards yet (Upgrade is not applied)

#### Scenario 13

- No one has claimed for more than a period since the upgrade

#### Rollover/hooks scenarios

- Campaign with rewards
- User has voted
- Campaign has rewards leftover

#### Scenario 14

- The campaign has a rollover mecanism

#### Scenario 15

- The campaign has a hook mecanism

### Closable/Closed campaign scenarios

- Campaign with rewards
- Campaign is in closable state

#### Scenario 16

- Manager can close the campaign

#### Scenario 17

- Manager has closed the campaign

#### Scenario 18

- Manager hasn't closed the campaign during the close window period