//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

contract MyOwnable {
    address internal _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }
}