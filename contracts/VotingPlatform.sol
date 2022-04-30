//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";
import "./VWallet.sol";
import "./VoteKeeper.sol";

/// @title Voting Platform
/// @author Mad Aekauq
/// @notice The voting platform allows to the owner to create new votings
/// and gives to users a possibility to vote for candidates, to request
/// results (when voting period ended) and, after the owner updates the results,
/// to finish votings rewarding the winners.
contract VotingPlatform is MyOwnable, VWallet, VoteKeeper {
    
    enum VotingState {
        InProcess,
        PendingResults,
        ReadyToFinish,
        Finished,
        ReadyToClose,
        Closed
    }

    struct Voting {
        uint endDate;
        uint winner;
        VotingState state;
        address[] candidates;
    }

    error NoSuchVoting();
    error VotingIsStillInProcess();
    error VotingPeriodEnded();
    error CandidatesRequired();
    error NoSuchCandidate();
    error IndexIsOutOfBoundaries(uint index);

    string constant ERR_WRONG_FEE = "Wrong fee";
    string constant ERR_INCORRECT_STATE = "Incorrect state for the action";

    event StateChanged(uint indexed objId, VotingState indexed state);

    uint private _votingDuration = 3 days;
    uint private _voteFee = 0.01 ether;
    uint private _comission = 10;//%

    Voting[] private _votings;
    
    modifier votingExists(uint id) {
        if(id >= _votings.length)
            revert NoSuchVoting();
        _;
    }

    modifier changeState(uint vId, VotingState expected, VotingState next) {
        require(_votings[vId].state == expected, ERR_INCORRECT_STATE);
        _votings[vId].state = next;
        
        _;

        emit StateChanged(vId, _votings[vId].state);
    }

    /// @notice The owner can set a duration for new votings
    /// @param newDuration a new duration (in seconds) for all new votings
    function SetDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    /// @notice Returns details about the requested voting
    /// @param id id of the voting
    /// @return voting description of the voting
    /// @return votes all votes in order they were given
    function GetVotingDetails(uint id) 
        external 
        view 
        votingExists(id)
        returns (Voting memory voting, Vote[] memory votes) 
    {
        return (_votings[id], GetVotes(id));
    }

    /// @notice Returns all votings in order they were created
    function GetVotings() external view returns (Voting[] memory) {
        return _votings;
    }

    /// @notice The owner can start a new voting
    /// @param candidates a list of candidates' addresses
    function AddVoting(address[] memory candidates) external onlyOwner {
        if (candidates.length == 0)
            revert CandidatesRequired();
        
        Voting memory newOne;
        newOne.endDate = block.timestamp + _votingDuration;
        newOne.candidates = candidates;
        newOne.state = VotingState.InProcess;
        _votings.push(newOne);
    }

    /// @notice Adds the vote and accumulates the reward
    /// @param vId id of the voting
    /// @param candidate address of the existing candidate
    function AddVote(uint vId, address candidate) 
        external 
        payable 
        votingExists(vId) 
    {
        require(msg.value == _voteFee, ERR_WRONG_FEE);
        if (_votings[vId].endDate <= block.timestamp)
            revert VotingPeriodEnded();
        if (!candidateExists(candidate, _votings[vId].candidates)) 
            revert NoSuchCandidate();

        AddNewVote(vId, msg.sender, candidate);
        AddToBalance(vId, msg.value);
    }

    /// @notice Makes the voting
    function CalculateResults(uint vId) 
        external 
        votingExists(vId)
        changeState(vId, VotingState.InProcess, VotingState.PendingResults)
    {
        if (_votings[vId].endDate > block.timestamp)
            revert VotingIsStillInProcess();
    }

    /// @notice The owner can update results of the voting.
    /// It changes the voting's state and emits a ReadyToFinish event 
    /// which can be used to notify a user who requested CalculateResults
    function UpdateVotingResult(uint vId, uint winnerId) 
        external
        onlyOwner
        votingExists(vId)
        changeState(
            vId, 
            VotingState.PendingResults, 
            VotingState.ReadyToFinish
        )
    {
        if (winnerId >= _votings[vId].candidates.length) 
            revert IndexIsOutOfBoundaries(winnerId);

        _votings[vId].winner = winnerId;
    }

    /// @notice Finishes the voting
    /// @param vId id of the voting
    function Finish(uint vId) 
        public 
        votingExists(vId)
        changeState(vId, VotingState.ReadyToFinish, VotingState.Finished)
    {
        Transfer(
            vId,
            _votings[vId].candidates[_votings[vId].winner], 
            applyComission(GetBalance(vId))
        );
        
        _votings[vId].state = VotingState.ReadyToClose;
    }

    /// @notice The owner can withdraw the comission taken during the voting
    /// @param vId id of the voting
    function Withdraw(uint vId) 
        external 
        onlyOwner 
        votingExists(vId) 
        changeState(vId, VotingState.ReadyToClose, VotingState.Closed)
    {
        Transfer(vId, _owner, GetBalance(vId));
    }

    /// @dev Checks if the element is in the array 
    function candidateExists(address a, address[] memory all) 
        internal 
        pure 
        returns (bool)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a)
                return true;
        }
        return false;
    }

    /// @dev DRY
    function applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
