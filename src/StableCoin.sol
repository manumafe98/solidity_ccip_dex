// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StableCoin is ERC20Burnable, Ownable {
    error StableCoin__AmountMustBeMoreThanZero();
    error StableCoin__BurnAmountExceedsBalance();
    error StableCoin__NotZeroAddress();

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert StableCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert StableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert StableCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
