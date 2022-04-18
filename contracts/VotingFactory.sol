//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//@title Voting system
//@author Mad Aekauq
//@notice Owner can start votings with the list of candidates.
//Then everone can vote, and after a voting finishes 
//the winner gets the reward.
contract VotingFactory is Ownable {

    //@dev keeps details about the voting
    struct Voting {
        uint32 endDate;
        address winner;
        address[] candidates;
    }
    //@dev keeps details about someone's vote (their decision)
    struct Vote {
        uint key;
        uint votingId;
        address owner;
        address candidate;
    }

    //@dev default duration of all votings
    uint constant VOTINGS_DURATION = 3 days;
    //@dev default limit for voters to vote in each voting
    uint constant VOTES_LIMIT_PER_VOTER = 1;
 
    Voting[] public votings;

    //@dev all votes to do calculations
    mapping(uint => Vote[]) _givenVotes;
    //@dev counters to check if a voter already voted in a voting
    mapping(uint => uint) _voteCounters;

    //@notice gives info about the requested voting
    function getVoting(uint id) external view returns (Voting memory, uint) {
        return (votings[id], _givenVotes[id].length);
    }

    //@dev starts a new voting with the listed candidates and 
    //calculating the end date
    function addVoting(address[] memory candidates) external onlyOwner {
        require(candidates.length > 0);
        
        Voting memory newOne;
        newOne.endDate = uint32(block.timestamp + VOTINGS_DURATION);
        newOne.candidates = candidates;
        votings.push(newOne);
    }

    //@dev sends accumulated fees to the owner
    function withdraw() external onlyOwner {
        //TODO 1: returns accumulated fees
    }

    //@dev checks if the voting isn't ended yet, 
    //if the voter hasn't voted yet
    //and saves voter's decision 
    function vote(uint votingId, address candidate) external {
        require(votings[votingId].endDate > block.timestamp);

        uint key = _getVoteKey(votingId, msg.sender);
        require(_voteCounters[key] < VOTES_LIMIT_PER_VOTER);
        
        _voteCounters[key]++;
        _givenVotes[votingId].push(
            Vote(key, votingId, msg.sender, candidate)
        );
    }

    //@dev checks if the voting exists and the end date has come already,
    //finds and saves the winner and sends the reward
    function finish(uint votingId) external view {
        require(
            votings[votingId].endDate > 0 && 
            votings[votingId].endDate < block.timestamp
        );
        //TODO 1: finish the vote with votingId
        //TODO 2: reward the winner (90%)
    }

    //@dev hashes the params to get a key
    function _getVoteKey(uint votingId, address voter) 
        private 
        pure 
        returns (uint) 
    {
        return uint(keccak256(abi.encodePacked(votingId, voter)));
    }
}
