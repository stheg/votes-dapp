//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/// @title VWallet (Voting Wallet)
/// @author Mad Aekauq
/// @notice This contract allows to keep several accounts with balances
contract VWallet {
    mapping(uint => uint) private _accounts;

    //TODO: implement modifier and use 'public' instead of 'internal'
    // modifier canChangeBalance(address caller) {
    //     //TODO: checks if caller can change balances and do transferring
    // }

    /// @notice Returns the balance of the specified account
    function GetBalance(uint accountId) public view returns (uint) {
        return _accounts[accountId];
    }

    /// @notice Increases the balance of the specified account
    function AddToBalance(uint accountId, uint amount) internal {
        _accounts[accountId] += amount;
    }

    /// @dev Transfers the amount from current address to the specified one, 
    /// decreasing the balance of the specified account
    function Transfer(uint accountId, address toAddress, uint amount) internal {
        if (amount == 0)
            return;
        // should we?
        // if (toAddress == address(0))
        //     revert();
        _accounts[accountId] -= amount;
        payable(toAddress).transfer(amount);
    }
}