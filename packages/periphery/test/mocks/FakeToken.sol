// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.19;

import {MockERC20} from "@forge-std/src/mocks/MockERC20.sol";

contract FakeToken is MockERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) {
        initialize(name, symbol, decimals);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
