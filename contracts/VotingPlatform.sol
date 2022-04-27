//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";

/// @title Voting Platform
/// @author Mad Aekauq
/// @notice The voting platform allows to the owner to create new votings
/// and gives to users a possibility to vote for candidates, to request
/// results (when voting period ended) and, after the owner updates the results,
/// to finish votings rewarding the winners.
contract VotingPlatform is MyOwnable {
    
    enum VotingState {
        InProcess,
        PendingResults,
        ReadyToFinish,
        Finished,
        Failed
    }

    struct Voting {
        uint endDate;
        uint winner;
        VotingState state;
        address[] candidates;
    }
    
    struct Vote {
        address owner;
        address candidate;
    }

    error NoSuchVoting();
    error CandidatesRequired();
    error VotingPeriodEnded();
    error VotesLimitExceeded();
    error NoSuchCandidate();
    error VotingIsStillInProcess();
    error IndexIsOutOfBoundaries(uint index);

    string constant ERR_WRONG_FEE = "Wrong fee";
    string constant ERR_CALC_REQUESTED = "Calculation was already requested";
    string constant ERR_NO_UPD_EXPECTED = "No updates expected";
    string constant ERR_NOT_READY_TO_FINISH = "Not ready to finish";
    string constant ERR_NOT_FINISHED = "Not finished";

    event PendingForResults(uint indexed vId);
    event ReadyToFinish(uint indexed vId);

    uint _votingDuration = 3 days;
    uint _voteFee = 0.01 ether;
    uint _comission = 10;//%

    Voting[] _votings;
    
    mapping(uint => uint) _balance;//vId => balance
    mapping(uint => Vote[]) _givenVotes;//vId => givenVotes

    modifier votingExists(uint id) {
        if(id >= _votings.length)
            revert NoSuchVoting();
        _;
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
        public 
        view 
        votingExists(id)
        returns (Voting memory voting, Vote[] memory votes) 
    {
        return (_votings[id], _givenVotes[id]);
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
        if (hasAlreadyVoted(msg.sender, _givenVotes[vId]))
            revert VotesLimitExceeded();
        (,bool found) = indexOf(candidate, _votings[vId].candidates);
        if (!found) 
            revert NoSuchCandidate();

        _givenVotes[vId].push(Vote(msg.sender, candidate));
        _balance[vId] += msg.value;
    }

    /// @notice Checks if the voting period ended, changes the state
    /// and emits a PendingForResults event to notify the owner or someone else
    function CalculateResults(uint vId) 
        external 
        votingExists(vId)
    {
        Voting memory v = _votings[vId];
        require(v.state == VotingState.InProcess, ERR_CALC_REQUESTED);
        if (v.endDate > block.timestamp)
            revert VotingIsStillInProcess();
        
        _votings[vId].state = VotingState.PendingResults;

        emit PendingForResults(vId);
    }

    /// @notice The owner can update results of the voting.
    /// It changes the voting's state and emits a ReadyToFinish event 
    /// which can be used to notify a user who requested CalculateResults
    function UpdateVotingResult(uint vId, uint winnerId) 
        external
        onlyOwner
        votingExists(vId)
    {
        require(
            _votings[vId].state == VotingState.PendingResults, 
            ERR_NO_UPD_EXPECTED
        );
        if (winnerId >= _votings[vId].candidates.length) 
            revert IndexIsOutOfBoundaries(winnerId);

        _votings[vId].winner = winnerId;
        _votings[vId].state = VotingState.ReadyToFinish;

        // it is split into 2 stages/functions to make it possible 
        // to verify the results outside and only then finish & reward
        emit ReadyToFinish(vId);
    }

    /// @notice Finishes the voting
    /// @param vId id of the voting
    function Finish(uint vId) public votingExists(vId) {
        require(
            _votings[vId].state == VotingState.ReadyToFinish, 
            ERR_NOT_READY_TO_FINISH
        );

        _votings[vId].state = VotingState.Finished;
        transfer(
            applyComission(_balance[vId]), 
            _votings[vId].candidates[_votings[vId].winner], 
            vId
        );
    }

    /// @notice The owner can withdraw the comission taken during the voting
    /// @param vId id of the voting
    function Withdraw(uint vId) external onlyOwner votingExists(vId) {
        require(
            _votings[vId].state == VotingState.Finished, 
            ERR_NOT_FINISHED
        );
        transfer(_balance[vId], _owner, vId);
    }

    /// @dev Transfers the amount from the voting balance. DRY
    function transfer(uint amount, address to, uint vId) internal {
        if (amount == 0)
            return;
        // should we?
        // if (to == address(0))
        //     revert();
        _balance[vId] -= amount;
        payable(to).transfer(amount);
    }

    /// @dev Checks if the voter has already voted   
    function hasAlreadyVoted(address voter, Vote[] memory votes) 
        internal
        virtual
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

    /// @dev Checks if the element is in the array 
    function indexOf(address a, address[] memory all) 
        internal 
        pure 
        returns (uint, bool)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a)
                return (i, true);//found
        }
        return (0, false);//not found
    }

    /// @dev DRY
    function applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
