//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

//@title Voting system
//@author Mad Aekauq
//@notice Owner can start votings with the list of candidates.
//Then everone can vote, and after a voting finishes the winner gets the reward.
contract VotingFactory is Ownable {

    //@dev keeps details about the voting
    struct Voting {
        uint32 endDate;
        bool finished;
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

    //@notice details about the requested voting
    function getVotingDetails(uint id) external view returns (Voting memory, Vote[] memory) {
        return (votings[id], _givenVotes[id]);
    }

    //@notice gives info about the requested voting
    function getVotings() external view returns (Voting[] memory) {
        return votings;
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
    //if the voter hasn't voted yet and then saves voter's decision 
    function vote(uint votingId, address candidate) external {
        require(votings[votingId].endDate > block.timestamp);

        uint key = uint(keccak256(abi.encodePacked(votingId, msg.sender)));
        require(_voteCounters[key] < VOTES_LIMIT_PER_VOTER);
        
        _voteCounters[key]++;
        _givenVotes[votingId].push(Vote(key, votingId, msg.sender, candidate));
    }

    //@dev checks if the voting exists and the end date has come already,
    //finds and saves the winner and sends the reward
    function finish(uint votingId) external {
        require(
            !votings[votingId].finished, 
            "the voting has been finished already"
        );
        require(
            votings[votingId].endDate > 0 && 
            votings[votingId].endDate < block.timestamp,
            "the voting can't be finished yet"
        );

        votings[votingId].finished = true;

        (uint firstWinner, bool twoWinnersSituation) = _findWinner(votingId);
        if (twoWinnersSituation) {
            //it is finished, but there is no winner
            //TODO: send money back to the voters
            return;
        }

        votings[votingId].winner = votings[votingId].candidates[firstWinner];
        //TODO: send 90% to the winner
    }

    function _getIndexOf(address a, address[] memory all) 
        internal 
        pure 
        returns (uint)
    {
        for (uint i = 0; i < all.length; i++) {
            if (all[i] == a) { return i; }
        }

        revert("no such address in the collection");
    }

    //@dev calculates the votes using internal structures and
    //checks if there are two or more winners (the same number of votes)
    //@return index of the first winner in the Voting's list of candidates
    function _findWinner(uint votingId) internal view returns (uint, bool) {
        uint[] memory votesFor;
        for (uint i = 0; i < votings[votingId].candidates.length; i++) {
            votesFor[i] = 0;
        }
        for (uint i = 0; i < _givenVotes[votingId].length; i++) {
            address c = _givenVotes[votingId][i].candidate;
            uint index = _getIndexOf(c, votings[votingId].candidates);
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
}
