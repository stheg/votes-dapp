//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";

/// @title Voting Platform
/// @author Mad Aekauq
/// @notice The owner can start votings with candidates.
/// Anyone can vote. After end dates come votings can be finished,
/// Winners will get their rewards after comissions are taken.
/// Then the owner can withdraw comissions.
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

    event PendingForResults(uint vId);

    uint _votingDuration = 3 days;
    uint _voteFee = 0.01 ether;
    uint _comission = 10;//%

    Voting[] _votings;
    
    mapping(uint => uint) _balance;//vId => balance
    mapping(uint => Vote[]) _givenVotes;//vId => givenVotes

    modifier votingExists(uint id) {
        require(id < _votings.length, "Voting doesn't exist");
        _;
    }

    /// @notice sets duration for new votings
    /// @param newDuration a new duration (in seconds) for all new votings
    function SetDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    /// @notice returns details about the requested voting
    /// @param id id of the voting
    /// @return voting description of the voting
    /// @return votes all given votes
    function GetVotingDetails(uint id) 
        public 
        view 
        votingExists(id)
        returns (Voting memory voting, Vote[] memory votes) 
    {
        return (_votings[id], _givenVotes[id]);
    }

    /// @notice returns all votings in order they were created
    function GetVotings() external view returns (Voting[] memory) {
        return _votings;
    }

    /// @notice starts a new voting with the specified candidates
    /// @param candidates a list of candidates' addresses
    function AddVoting(address[] memory candidates) external onlyOwner {
        require(candidates.length > 0, "needs candidates");
        
        Voting memory newOne;
        newOne.endDate = block.timestamp + _votingDuration;
        newOne.candidates = candidates;
        newOne.state = VotingState.InProcess;
        _votings.push(newOne);
    }

    /// @notice saves voter's decision and increases the balance of the voting
    /// @param vId id of the voting
    /// @param candidate address of the existing candidate
    function AddVote(uint vId, address candidate) 
        external 
        payable 
        votingExists(vId) 
    {
        require(msg.value == _voteFee, "Wrong price");
        require(_votings[vId].endDate > block.timestamp, "Voting period ended");
        require(
            !hasAlreadyVoted(msg.sender, _givenVotes[vId]),
            "Votes limit"
        );
        (,bool found) = indexOf(candidate, _votings[vId].candidates);
        require(found, "no such candidate");

        _givenVotes[vId].push(Vote(msg.sender, candidate));
        _balance[vId] += msg.value;
    }

    /// @notice Checks if voting can be finished 
    /// and sets its state to CalculatingResults.
    /// Returns details to do all calculations outside.
    function CalculateResults(uint vId) 
        external 
        votingExists(vId)
    {
        Voting memory v = _votings[vId];
        require(v.state == VotingState.InProcess, "calculation was already requested");
        require(v.endDate < block.timestamp, "can't be finished yet");
        
        _votings[vId].state = VotingState.PendingResults;

        emit PendingForResults(vId);
    }

    function UpdateVotingResult(uint vId, uint winnerId) 
        external
        onlyOwner
        votingExists(vId)
    {
        require(
            _votings[vId].state == VotingState.PendingResults, 
            "voting doesn't expect updates"
        );
        require(
            winnerId < _votings[vId].candidates.length, 
            "winner is out of boundaries"
        );
        
        _votings[vId].winner = winnerId;
        _votings[vId].state = VotingState.ReadyToFinish;

        //TODO: implement event to make it possible to finish from outside
        // it is split into 2 stages/functions to make it possible 
        // to verify the results outside and only then finish & reward
        // emit ReadyToFinish(vId);
        Finish(vId);
    }

    /// @notice finishes the voting and sends the reward
    /// @param vId id of the voting
    function Finish(uint vId) public votingExists(vId) {
        require(
            _votings[vId].state == VotingState.ReadyToFinish, 
            "voting isn't ready to finish"
        );

        _votings[vId].state = VotingState.Finished;
        transfer(
            applyComission(_balance[vId]), 
            _votings[vId].candidates[_votings[vId].winner], 
            vId
        );
    }

    /// @notice transfers the taken comission to the owner of the platform
    /// @param vId id of the voting
    function Withdraw(uint vId) external onlyOwner votingExists(vId) {
        require(
            _votings[vId].state == VotingState.Finished, 
            "Voting isn't finished"
        );
        transfer(_balance[vId], _owner, vId);
    }

    /// @dev transfers the amount from the voting balance. DRY
    function transfer(uint amount, address to, uint vId) internal {
        if (amount == 0)
            return;
        _balance[vId] -= amount;
        payable(to).transfer(amount);
    }

    /// @dev checks if voter has already voted   
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

    /// @dev reverts if the element isn't found in the array 
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
