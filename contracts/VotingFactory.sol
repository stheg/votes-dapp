//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//@title Voting system
//@author Mad Aekauq
//@notice Owner can start _votings with the list of candidates.
//Then everone can vote, and after a voting finishes the winner gets the reward.
contract VotingFactory is Ownable {

    enum VotingState {
        InProcess,
        CalculatingResults,
        Finished
    }

    struct Voting {
        uint32 endDate;
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
    
    mapping(uint => uint) _balance;//votingId => balance
    mapping(uint => Vote[]) internal _givenVotes;//votingId => givenVotes
    mapping(uint => uint) internal _voteCounters;//Vote.key => counter

    //@dev useful for testing
    function setVotingDuration(uint newDuration) external onlyOwner {
        _votingDuration = newDuration;
    }

    //@notice returns details about the requested voting
    function getVotingDetails(uint id) 
        external 
        view 
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
        newOne.endDate = uint32(block.timestamp + _votingDuration);
        newOne.candidates = candidates;
        newOne.state = VotingState.InProcess;
        _votings.push(newOne);
    }

    //@dev sends accumulated fees to the owner
    function withdraw(uint votingId) external onlyOwner {
        require(
            _votings[votingId].state == VotingState.Finished, 
            "Voting isn't finished yet"
        );
        _transfer(_balance[votingId], owner(), votingId);
    }

    //@dev checks if the voting isn't ended yet, 
    //if the voter hasn't voted yet and then saves voter's decision 
    function vote(uint votingId, address candidate) external payable {
        require(msg.value == _voteFee, "Wrong value");
        require(
            _votings[votingId].endDate > block.timestamp,
            "Voting period ended"
        );

        uint key = uint(keccak256(abi.encodePacked(votingId, msg.sender)));
        require(
            _voteCounters[key] < _votesLimitPerVoter,
            "Votes limit is exceeded"
        );
        
        _voteCounters[key]++;
        _givenVotes[votingId].push(Vote(key, msg.sender, candidate));
        _balance[votingId] += msg.value;
    }

    //@dev checks if the voting exists and the end date has come already,
    //finds and saves the winner and sends the reward
    function finish(uint votingId) external {
        Voting storage voting = _votings[votingId];
        require(
            voting.state == VotingState.InProcess, 
            "The voting finished already"
        );
        require(
            voting.endDate > 0 && 
            voting.endDate < block.timestamp,
            "The voting can't be finished yet"
        );

        voting.state = VotingState.CalculatingResults;

        (uint firstWinner, bool twoWinnersSituation) = _findWinner(votingId);
        if (twoWinnersSituation) {
            for (uint i = 0; i < _givenVotes[votingId].length; i++) {
                _transfer(
                    _applyComission(_voteFee), 
                    _givenVotes[votingId][i].owner, 
                    votingId
                );
            }
        } else {
            voting.winner = voting.candidates[firstWinner];
            _transfer(
                _applyComission(_balance[votingId]), 
                voting.winner, 
                votingId
            );
        }
        voting.state = VotingState.Finished;
    }

    //@dev transfers the amount from the voting balance to the specified address
    function _transfer(uint amount, address to, uint votingId) internal {
        _balance[votingId] -= amount;
        payable(to).transfer(amount);        
    }

    //@dev calculates the votes using internal structures and
    //checks if there are two or more winners (the same number of votes)
    //@return index of the first winner in the Voting's list of candidates
    function _findWinner(uint votingId) internal view returns (uint, bool) {
        uint[] memory votesFor;
        for (uint i = 0; i < _votings[votingId].candidates.length; i++) {
            votesFor[i] = 0;
        }
        for (uint i = 0; i < _givenVotes[votingId].length; i++) {
            address c = _givenVotes[votingId][i].candidate;
            uint index = _getIndexOf(c, _votings[votingId].candidates);
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

    function _getIndexOf(address a, address[] memory all) 
        internal 
        pure 
        returns (uint)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a) { 
                return i; 
            }
        }

        revert("no such address in the collection");
    }

    function _applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
