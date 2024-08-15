// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import "solady/src/tokens/ERC20.sol";

contract StampedToken is ERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address public immutable factory;

    error UNAUTHORIZED();

    modifier onlyFactory() {
        if (msg.sender != factory) revert UNAUTHORIZED();
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        factory = msg.sender;

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) public onlyFactory {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyFactory {
        _burn(from, amount);
    }
}
