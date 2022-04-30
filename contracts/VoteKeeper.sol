//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

/// @title Vote Keeper
/// @author Mad Aekauq
/// @notice Keeps and registers new votes
contract VoteKeeper {

    struct Vote {
        address owner;
        address candidate;
    }

    error VotesLimitExceeded();

    mapping(uint => Vote[]) private _votes;

    /// @notice Returns all votes registered for the specified voting 
    function GetVotes(uint votingId) public view returns (Vote[] memory) {
        return _votes[votingId];
    }

    /// @notice Checks if can be added and then adds a new vote
    /// @param votingId id of the voting
    /// @param candidate address of the existing candidate
    function AddNewVote(uint votingId, address voter, address candidate) 
        internal
    {
        if (hasAlreadyVoted(voter, _votes[votingId]))
            revert VotesLimitExceeded();
        
        _votes[votingId].push(Vote(msg.sender, candidate));
    }

    /// @dev Checks if the voter has already voted   
    function hasAlreadyVoted(address voter, Vote[] memory votes) 
        private
        pure
        returns (bool)
    {
        for (uint i = 0; i < votes.length; i++) {
            if (votes[i].owner == voter) {
                return true; 
            }
        }
        return false;
    }
}