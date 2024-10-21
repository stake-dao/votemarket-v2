// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "@votemarket/src/interfaces/IVotemarket.sol";

abstract contract VM {
    function updateEpoch(address platform, uint256 campaignId, uint256 epoch, bytes calldata hookData) external {
        IVotemarket(platform).updateEpoch(campaignId, epoch, hookData);
    }

    function claim(address platform, uint256 campaignId, address account, uint256 epoch, bytes calldata hookData)
        external
        returns (uint256 claimed)
    {
        return IVotemarket(platform).claim(campaignId, account, epoch, hookData);
    }
}