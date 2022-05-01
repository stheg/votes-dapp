//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/// @title Voting State Keeper
/// @author Mad Aekauq
/// @notice Allows to keep and control states of votings 
contract VStateKeeper {

    enum VotingState {
        InProcess,
        PendingResults,
        ReadyToFinish,
        Finished,
        ReadyToClose,
        Closed
    }

    string constant ERR_INCORRECT_STATE = "Incorrect state for the action";

    event StateChanged(uint indexed votingId, VotingState indexed state);

    mapping(uint => VotingState) private _states;//votingId => state

    /// @notice Ensures that the current state is the expected one and
    /// updates it to the next one. After the body-function is finished,
    /// it emits StateChanged event
    modifier changeStateOnce(uint id, VotingState expected, VotingState next) 
    {
        require(_states[id] == expected, ERR_INCORRECT_STATE);
        _states[id] = next;
        
        _;

        // in case the body-function changes the state 
        // we should return the correct one
        emit StateChanged(id, _states[id]); 
    }

    /// @notice Ensures that the current state is the expected one and
    /// updates it to the next one. After the body-function is finished,
    /// it changes the state one more time and then emits StateChanged event
    modifier changeStateTwice(
        uint id, 
        VotingState expected, 
        VotingState next,
        VotingState inTheEnd
    ) {
        require(_states[id] == expected, ERR_INCORRECT_STATE);
        _states[id] = next;
        
        _;

        _states[id] = inTheEnd;
        emit StateChanged(id, inTheEnd);
    }
}