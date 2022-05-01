//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";

/// @title Voting Keeper
/// @author Mad Aekauq
/// @notice Keeps and registers new votings
contract VotingKeeper is MyOwnable {

    struct Voting {
        uint endDate;
        uint winner;
        address[] candidates;
    }

    error NoSuchVoting();
    error NoSuchCandidate();
    error CandidatesRequired();
    error IndexIsOutOfBoundaries(uint index);
    
    uint private _votingDuration = 3 days;
    Voting[] private _votings;

    /// @notice Reverts if a voting isn't found
    modifier checkVotingExists(uint id) {
        if(id >= _votings.length)
            revert NoSuchVoting();
        _;
    }

    /// @notice The owner can set a duration for all new votings
    /// @param newDuration a new duration (in seconds) for all new votings
    function SetDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    /// @notice Returns all votings in order they were created
    function GetVotings() public view returns (Voting[] memory) {
        return _votings;
    }

    /// @notice Returns a voting with the specified id
    function GetVoting(uint id) public view returns (Voting memory) {
        return _votings[id];
    }

    /// @notice The owner can start a new voting, reverts if no candidates
    /// @param candidates a list of candidates' addresses
    function AddVoting(address[] memory candidates) public onlyOwner {
        if (candidates.length == 0)
            revert CandidatesRequired();
        
        Voting memory newOne;
        newOne.endDate = block.timestamp + _votingDuration;
        newOne.candidates = candidates;
        _votings.push(newOne);
    }

    /// @notice Checks if a voting period ended
    function VotingPeriodEnded(uint id) public view returns (bool) {
        return _votings[id].endDate <= block.timestamp;
    }

    /// @notice Ensures that the given candidate is correct
    function CheckCandidate(uint id, address candidate) 
        public 
        view 
        returns (bool) 
    {
        address[] memory candidates = _votings[id].candidates;
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i] == candidate)
                return true;
        }
        return false;
    }

    /// @notice Reverts if winner is outside of candidates list  
    function SetTheWinner(uint id, uint winnerId) internal {
        if (winnerId >= _votings[id].candidates.length) 
            revert IndexIsOutOfBoundaries(winnerId);

        _votings[id].winner = winnerId;
    }

    /// @notice Returns the address of the winner
    function GetWinnerAddress(uint id) public view returns (address) {
        return _votings[id].candidates[_votings[id].winner];
    }
}