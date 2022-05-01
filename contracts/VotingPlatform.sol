//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./MyOwnable.sol";
import "./VWallet.sol";
import "./VoteKeeper.sol";
import "./VotingKeeper.sol";
import "./VStateMachine.sol";

/// @title Voting Platform
/// @author Mad Aekauq
/// @notice The voting platform allows to the owner to create new votings
/// and gives to users a possibility to vote for candidates, to request
/// results (when voting period ended) and, after the owner updates the results,
/// to finish votings rewarding the winners.
contract VotingPlatform is 
    MyOwnable, 
    VWallet, 
    VotingKeeper, 
    VoteKeeper,
    VStateMachine 
{
    string constant ERR_WRONG_FEE = "Wrong fee";
    string constant ERR_VOTING_PERIOD_ENDED = "Voting period ended";
    string constant ERR_VOTING_IS_IN_PROCESS = "Voting is still in process";
    string constant ERR_NO_SUCH_CANDIDATE = "No such candidate";

    uint private _voteFee = 0.01 ether;
    uint private _comission = 10;//%

    /// @notice Returns all details about the requested voting
    /// @param id id of the voting
    /// @return voting description of the voting
    /// @return votes all votes in order they were given
    function GetVotingDetails(uint id) 
        external 
        view 
        checkVotingExists(id)
        returns (Voting memory voting, Vote[] memory votes) 
    {
        return (GetVoting(id), GetVotes(id));
    }

    /// @notice Adds the vote and accumulates the reward
    /// @param vId id of the voting
    /// @param candidate address of the existing candidate
    function AddVote(uint vId, address candidate) 
        external 
        payable 
        checkVotingExists(vId)
    {
        require(msg.value == _voteFee, ERR_WRONG_FEE);
        require(!VotingPeriodEnded(vId), ERR_VOTING_PERIOD_ENDED);
        require(CheckCandidate(vId, candidate), ERR_NO_SUCH_CANDIDATE);

        AddNewVote(vId, msg.sender, candidate);
        AddToBalance(vId, msg.value);
    }

    /// @notice Changes a state allowing the owner to define the winner 
    function CalculateResults(uint vId) 
        external 
        checkVotingExists(vId)
        changeStateOnce(vId, VotingState.InProcess, VotingState.PendingResults)
    {
        require(VotingPeriodEnded(vId), ERR_VOTING_IS_IN_PROCESS);
    }

    /// @notice The owner can define the winner.
    function UpdateVotingResult(uint vId, uint winnerId) 
        external
        onlyOwner
        checkVotingExists(vId)
        changeStateOnce(
            vId, 
            VotingState.PendingResults, 
            VotingState.ReadyToFinish
        )
    {
        SetTheWinner(vId, winnerId);
    }

    /// @notice Finishes the voting
    /// @param vId id of the voting
    function Finish(uint vId) 
        public 
        checkVotingExists(vId)
        changeStateTwice(
            vId, 
            VotingState.ReadyToFinish, 
            VotingState.Finished, 
            VotingState.ReadyToClose
        )
    {
        Transfer(vId, GetWinnerAddress(vId), applyComission(GetBalance(vId)));
    }

    /// @notice The owner can withdraw the comission taken during the voting
    /// @param vId id of the voting
    function Withdraw(uint vId) 
        external 
        onlyOwner 
        checkVotingExists(vId) 
        changeStateOnce(vId, VotingState.ReadyToClose, VotingState.Closed)
    {
        Transfer(vId, _owner, GetBalance(vId));
    }

    /// @dev DRY
    function applyComission(uint input) internal view returns (uint) {
        return input * (100 - _comission) / 100;
    }
}
