// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Finance interface.
 */
contract Finance is Ownable {
    ERC20 internal daiToken;
    mapping(address => uint256) private holdings;
    constructor(address daiAddr) Ownable() {daiToken = ERC20(daiAddr);}

    function deposit(uint256 _amount) external onlyOwner {
        holdings[owner()] = holdings[owner()] + _amount;
    }

    function transfer_dai(address to, uint256 amount) external onlyOwner {
        daiToken.transferFrom(address(this), to, amount);
        holdings[owner()] = holdings[owner()] - amount;
    }
}
