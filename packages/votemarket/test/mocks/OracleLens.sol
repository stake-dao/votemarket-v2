// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

contract MockOracleLens {
    mapping(address => mapping(uint256 => uint256)) private totalVotes;
    mapping(address => mapping(address => mapping(uint256 => uint256))) private accountVotes;

    function canClaim(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function setTotalVotes(address gauge, uint256 epoch, uint256 votes) external {
        totalVotes[gauge][epoch] = votes;
    }

    function setAccountVotes(address account, address gauge, uint256 epoch, uint256 votes) external {
        accountVotes[account][gauge][epoch] = votes;
    }

    function getTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {
        return totalVotes[gauge][epoch];
    }

    function getAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {
        return accountVotes[account][gauge][epoch];
    }

    // Implement other functions from IOracleLens if needed for your tests
    function getPastTotalVotes(address gauge, uint256 epoch) external view returns (uint256) {
        return totalVotes[gauge][epoch];
    }

    function getPastAccountVotes(address account, address gauge, uint256 epoch) external view returns (uint256) {
        return accountVotes[account][gauge][epoch];
    }
}
