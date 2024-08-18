// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

contract MockOracleLens {
    mapping(address => uint256) private totalVotes;
    mapping(address => mapping(address => uint256)) private accountVotes;

    function canClaim(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function setTotalVotes(address gauge, uint256 epoch, uint256 votes) external {
        totalVotes[gauge] = votes;
    }

    function setAccountVotes(address account, address gauge, uint256 epoch, uint256 votes) external {
        accountVotes[account][gauge] = votes;
    }

    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {
        return totalVotes[gauge];
    }

    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {
        return accountVotes[account][gauge];
    }
}

contract MockVulnerableOracleLens {
    function canClaim(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function getAccountVotes(address, address, uint256) external pure returns (uint256) {
        return 100e18;
    }

    function getTotalVotes(address, uint256) external pure returns (uint256) {
        return 1000e18;
    }
}
