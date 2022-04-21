//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";

/// @title Voting Platform
/// @author Mad Aekauq
/// @notice The owner can start votings with candidates.
/// Anyone can vote, what accumulates rewards.
/// After end dates come votings can be finished, and 
/// winners will get their rewards after a comission is taken.
/// Then the owner can withdraw comissions.
contract VotingPlatform is MyOwnable {

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
        //uint key;
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
    /// @return descr description of the voting
    /// @return votes all given votes
    function getVotingDetails(uint id) 
        external 
        view 
        votingExists(id)
        returns (Voting memory descr, Vote[] memory votes) 
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
        require(candidates.length > 1, "at least 2 candidates expected");
        require(elementsUnique(candidates), "candidates should be unique");
        
        Voting memory newOne;
        newOne.startDate = block.timestamp;
        newOne.endDate = newOne.startDate + _votingDuration;
        newOne.candidates = candidates;
        newOne.state = VotingState.InProcess;
        _votings.push(newOne);
    }

    /// @notice transfers the taken comission to the owner of the platform
    /// @param vId id of the voting
    function withdraw(uint vId) external onlyOwner votingExists(vId) {
        require(
            _votings[vId].state == VotingState.Finished, 
            "Voting isn't finished yet"
        );
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
        require(msg.value == _voteFee, "Wrong value");
        Voting memory voting = _votings[vId];
        require(voting.endDate > block.timestamp, "Voting period ended");

        require(
            !_hasAlreadyVoted(msg.sender, _givenVotes[vId]),
            "Votes limit is exceeded"
        );
        //checks if the candidate exists, otherwise reverts
        indexOf(candidate, voting.candidates);
        
        _givenVotes[vId].push(Vote(msg.sender, candidate));
        _balance[vId] += msg.value;
    }

    /// @notice finishes the voting and sends the reward
    /// @param vId id of the voting
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
        //it shouldn't be possible to finish again
        //and it shouldn't be possible to withdraw until it is finihed.
        //so we use this special state here
        voting.state = VotingState.CalculatingResults;

        (uint winner, bool controversialSituation) = _findWinner(vId);
        if (controversialSituation) {
            Vote[] memory votes = _givenVotes[vId];
            for (uint i = 0; i < votes.length; i++) {
                _transfer(_applyComission(_voteFee), votes[i].owner, vId);
            }
        } else {
            voting.winner = voting.candidates[winner];
            _transfer(_applyComission(_balance[vId]), voting.winner, vId);
        }
        voting.state = VotingState.Finished;
    }

    /// @dev transfers the amount from the voting balance. DRY
    function _transfer(uint amount, address to, uint vId) internal {
        _balance[vId] -= amount;
        payable(to).transfer(amount);
    }

    /// @dev calculates the votes using internal structures and
    /// checks if there are two or more winners (the same number of votes)
    /// @param vId id of the voting
    /// @return winnerIndex the first winner in the Voting's list of candidates
    /// @return controversialSituation true, if more than 1 winner
    function _findWinner(uint vId) 
        internal 
        virtual 
        view 
        returns (uint winnerIndex, bool controversialSituation) 
    {
        Voting memory voting = _votings[vId];
        Vote[] memory givenVotes = _givenVotes[vId];
        
        uint maxVal = 0;
        winnerIndex = 0;
        
        uint[] memory votesFor = new uint[](voting.candidates.length);
        for (uint i = 0; i < givenVotes.length; i++) {
            uint cand = indexOf(givenVotes[i].candidate, voting.candidates);
            votesFor[cand]++;

            //get the max right here to avoid second For-loop
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

    /// @dev checks if `votes` contains an element with owner == `voter`   
    function _hasAlreadyVoted(address voter, Vote[] memory votes) 
        internal
        virtual
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < votes.length; i++) {
            if (votes[i].owner == voter) {
                return true; 
            }
        }
        return false;
    }

    /// @dev checks if all elements of `list` are unique
    function elementsUnique(address[] memory list) 
        internal 
        pure 
        returns (bool) 
    {
        for (uint256 i = 0; i < list.length; i++) {
            for (uint256 j = i + 1; j < list.length; j++) {
                if (list[i] == list[j])
                    return false;
            }
        }
        return true;
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

        revert("no such candidate in the collection");
    }

    /// @dev DRY
    function _applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
