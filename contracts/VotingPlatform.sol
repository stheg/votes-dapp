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

    struct Voting {
        uint endDate;
        uint state;
        uint winner;
        address[] candidates;
    }
    
    struct Vote {
        address owner;
        address candidate;
    }

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
    function setDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    /// @notice returns details about the requested voting
    /// @param id id of the voting
    /// @return voting description of the voting
    /// @return votes all given votes
    function getVotingDetails(uint id) 
        external 
        view 
        votingExists(id)
        returns (Voting memory voting, Vote[] memory votes) 
    {
        return (_votings[id], _givenVotes[id]);
    }

    /// @notice returns all votings in order they were created
    function getVotings() external view returns (Voting[] memory) {
        return _votings;
    }

    /// @notice starts a new voting with the specified candidates
    /// @param candidates a list of candidates' addresses
    function addVoting(address[] memory candidates) external onlyOwner {
        require(candidates.length > 0, "needs candidates");
        
        Voting memory newOne;
        newOne.endDate = block.timestamp + _votingDuration;
        newOne.candidates = candidates;
        newOne.state = 0;//in process
        _votings.push(newOne);
    }

    /// @notice transfers the taken comission to the owner of the platform
    /// @param vId id of the voting
    function withdraw(uint vId) external onlyOwner votingExists(vId) {
        require(_votings[vId].state == 2, "Voting isn't finished");
        _transfer(_balance[vId], _owner, vId);
    }

    /// @notice saves voter's decision and increases the balance of the voting
    /// @param vId id of the voting
    /// @param candidate address of the existing candidate
    function vote(uint vId, address candidate) 
        external 
        payable 
        votingExists(vId) 
    {
        require(msg.value == _voteFee, "Wrong price");
        require(_votings[vId].endDate > block.timestamp, "Voting period ended");

        require(
            !_hasAlreadyVoted(msg.sender, _givenVotes[vId]),
            "Votes limit"
        );
        //checks if the candidate exists, otherwise reverts
        indexOf(candidate, _votings[vId].candidates);
        
        _givenVotes[vId].push(Vote(msg.sender, candidate));
        _balance[vId] += msg.value;
    }

    /// @notice finishes the voting and sends the reward
    /// @param vId id of the voting
    function finish(uint vId) external votingExists(vId) {
        Voting memory v = _votings[vId];
        require(v.state == 0, "finished already");
        require(v.endDate < block.timestamp, "can't be finished yet");
        
        _votings[vId].state = 1;//calculating results

        (uint winner, bool controversialSituation) = _findWinner(
            v.candidates, 
            _givenVotes[vId]
        );
        if (controversialSituation) {
            handleControversialSituation(vId);
        } else {
            _votings[vId].winner = winner;
            _transfer(
                _applyComission(_balance[vId]), 
                _votings[vId].candidates[winner], 
                vId
            );
        }
        _votings[vId].state = 2;//finished
    }

    /// @dev transfers the amount from the voting balance. DRY
    function _transfer(uint amount, address to, uint vId) internal {
        _balance[vId] -= amount;
        payable(to).transfer(amount);
    }

    /// @dev calculates the votes using internal structures and
    /// checks if there are two or more winners (the same number of votes)
    /// @return winnerIndex the first winner in the Voting's list of candidates
    /// @return controversialSituation true, if more than 1 winner
    function _findWinner(address[] memory candidates, Vote[] memory votes) 
        internal 
        virtual 
        view 
        returns (uint winnerIndex, bool controversialSituation) 
    {
        uint maxVal = 0;
        winnerIndex = 0;
        
        uint[] memory votesFor = new uint[](candidates.length);
        for (uint i = 0; i < votes.length; i++) {
            uint cand = indexOf(votes[i].candidate, candidates);
            votesFor[cand]++;

            if (votesFor[cand] > maxVal) {
                maxVal = votesFor[cand];
                winnerIndex = cand;
            }
        }

        controversialSituation = false;
        for (uint i = 0; i < votesFor.length; i++) {
            if (i != winnerIndex && votesFor[i] == maxVal) {
                controversialSituation = true;
                break;
            }
        }

        return (winnerIndex, controversialSituation);
    }

    /// @dev defines what we should do in case if we don't have the winner 
    function handleControversialSituation(uint vId) internal virtual {
        //revert("controversial situation");
        for (uint i = 0; i < _givenVotes[vId].length; i++) {
            _transfer(
                _applyComission(_voteFee), 
                _givenVotes[vId][i].owner, 
                vId
            );
        }
    }

    /// @dev checks if voter has already voted   
    function _hasAlreadyVoted(address voter, Vote[] memory votes) 
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
        returns (uint)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a)
                return i;
        }

        revert("no such candidate");
    }

    /// @dev DRY
    function _applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
