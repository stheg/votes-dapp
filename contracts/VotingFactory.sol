//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";

//@title Voting system
//@author Mad Aekauq
//@notice Owner can start _votings with the list of candidates.
//Then everone can vote, and after a voting finishes the winner gets the reward.
contract VotingFactory is MyOwnable {

    enum VotingState {
        InProcess,
        CalculatingResults,
        Finished
    }

    struct Voting {
        uint startDate;
        uint endDate;
        VotingState state;
        address winner;
        address[] candidates;
    }
    
    struct Vote {
        uint key;
        address owner;
        address candidate;
    }

    uint internal _votingDuration = 3 days;
    uint internal _votesLimitPerVoter = 1;

    uint internal _voteFee = 0.01 ether;
    uint internal _comission = 10;//%

    Voting[] internal _votings;
    
    mapping(uint => uint) _balance;//vId => balance
    mapping(uint => Vote[]) internal _givenVotes;//vId => givenVotes
    mapping(uint => uint) internal _voteCounters;//Vote.key => counter

    modifier votingExists(uint id) {
        require(id < _votings.length, "Voting doesn't exist");
        _;
    }

    //@dev useful for testing
    function setDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    //@notice returns details about the requested voting
    function getVotingDetails(uint id) 
        external 
        view 
        votingExists(id)
        returns (Voting memory, Vote[] memory) 
    {
        return (_votings[id], _givenVotes[id]);
    }

    //@notice returns all votings
    function getVotings() external view returns (Voting[] memory) {
        return _votings;
    }

    //@dev starts a new voting with the listed candidates and 
    //calculating the end date
    function addVoting(address[] memory candidates) external onlyOwner {
        require(candidates.length > 1, "at least 2 candidates expected");
        
        Voting memory newOne;
        newOne.startDate = block.timestamp;
        newOne.endDate = newOne.startDate + _votingDuration;
        newOne.candidates = candidates;
        newOne.state = VotingState.InProcess;
        _votings.push(newOne);
    }

    //@dev sends accumulated fees to the owner
    function withdraw(uint vId) external onlyOwner votingExists(vId) {
        require(
            _votings[vId].state == VotingState.Finished, 
            "Voting isn't finished yet"
        );
        _transfer(_balance[vId], _owner, vId);
    }

    //@dev checks if the voting isn't ended yet, 
    //if the voter hasn't voted yet and then saves voter's decision 
    function vote(uint vId, address candidate) 
        external 
        payable 
        votingExists(vId) 
    {
        require(msg.value == _voteFee, "Wrong value");
        Voting memory voting = _votings[vId];
        require(
            voting.endDate > block.timestamp,
            "Voting period ended"
        );

        uint key = uint(keccak256(abi.encodePacked(vId, msg.sender)));
        require(
            _voteCounters[key] < _votesLimitPerVoter,
            "Votes limit is exceeded"
        );
        //checks if the candidate exists, otherwise reverts
        _getIndexOfCandidate(candidate, voting.candidates);
        
        _voteCounters[key]++;
        _givenVotes[vId].push(Vote(key, msg.sender, candidate));
        _balance[vId] += msg.value;
    }

    //@dev checks if the voting exists and the end date has come already,
    //finds and saves the winner and sends the reward
    function finish(uint vId) external votingExists(vId) {
        Voting storage voting = _votings[vId];
        require(
            voting.state == VotingState.InProcess, 
            "The voting finished already"
        );
        require(
            voting.endDate < block.timestamp,
            "The voting can't be finished yet"
        );

        voting.state = VotingState.CalculatingResults;

        (uint firstWinner, bool twoWinnersSituation) = _findWinner(vId);
        if (twoWinnersSituation) {
            for (uint i = 0; i < _givenVotes[vId].length; i++) {
                _transfer(
                    _applyComission(_voteFee), 
                    _givenVotes[vId][i].owner, 
                    vId
                );
            }
        } else {
            voting.winner = voting.candidates[firstWinner];
            _transfer(_applyComission(_balance[vId]), voting.winner, vId);
        }
        voting.state = VotingState.Finished;
    }

    //@dev transfers the amount from the voting balance to the specified address
    function _transfer(uint amount, address to, uint vId) internal {
        _balance[vId] -= amount;
        payable(to).transfer(amount);
    }

    //@dev calculates the votes using internal structures and
    //checks if there are two or more winners (the same number of votes)
    //@return index of the first winner in the Voting's list of candidates
    function _findWinner(uint vId) internal view returns (uint, bool) {
        uint[] memory votesFor = new uint[](_votings[vId].candidates.length);
        for (uint i = 0; i < _givenVotes[vId].length; i++) {
            address c = _givenVotes[vId][i].candidate;
            uint index = _getIndexOfCandidate(c, _votings[vId].candidates);
            votesFor[index]++;
        }

        uint maxVal = votesFor[0];
        uint firstMaxIndex = 0;
        for (uint i = 1; i < votesFor.length; i++) {
            if (votesFor[i] > maxVal) {
                maxVal = votesFor[i];
                firstMaxIndex = i;
            }
        }
        bool twoWinnersSituation = false;
        for (uint i = firstMaxIndex + 1; i < votesFor.length; i++) {
            if (votesFor[i] == maxVal) {
                twoWinnersSituation = true;
                break;
            }
        }

        return (firstMaxIndex, twoWinnersSituation);
    }

    function _getIndexOfCandidate(address a, address[] memory all) 
        internal 
        pure 
        returns (uint)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a) { 
                return i; 
            }
        }

        revert("no such candidate in the collection");
    }

    function _applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
