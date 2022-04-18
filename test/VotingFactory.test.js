const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("VotingFactory", function () {
  let owner
  let cand1, cand2
  let p1, p2, p3
  let votingSys

  beforeEach(async function() {
    [owner, cand1, cand2, p1, p2, p3] = await ethers.getSigners();
    const VotingFactory = 
      await ethers.getContractFactory("VotingFactory", owner);
    votingSys = await VotingFactory.deploy();
    await votingSys.deployed();
  })
  
  it("should set duration only by owner", async function () {
    await checkCallByOwnerOnly(async function (sender) { 
      await votingSys.connect(sender).setVotingDuration(5);
    });
  });
  
  it("should add a new voting only by owner", async function () {
    await checkCallByOwnerOnly(async function (sender) {
      await votingSys.connect(sender).addVoting([cand1.address, cand2.address]);
      let v = await votingSys.getVotings();
      expect(v.length).eq(1);
    });
  });

  it("should require candidates for a new voting", async function () {
    let err;
    try {
      await votingSys.addVoting([]);
    } catch (error) {
      err = error;
    }
    expect(err).is.not.undefined;
  });

  it("should be possible to have more than 1 voting", async function () {
    await votingSys.addVoting([cand1.address, cand2.address]);
    await votingSys.addVoting([cand1.address, cand2.address]);

    let v = await votingSys.getVotings();
    expect(v.length).eq(2);
  });
 
  it("should add a new vote from p1 for cand1", async function () {
    await votingSys.addVoting([cand1.address, cand2.address]);
    let votingId = 0;
    await votingSys.connect(p1).vote(votingId, cand1.address);

    let v = await votingSys.getVotingDetails(votingId);
    let votes = v[1];
    expect(votes.length).eq(1);
    expect(votes[0].owner).eq(p1.address);
    expect(votes[0].candidate).eq(cand1.address);
  });

  it("shouldn't exceed vote limit from p1", async function () {
    //by default the limit = 1
    await votingSys.addVoting([cand1.address, cand2.address]);
    let votingId = 0;
    await votingSys.connect(p1).vote(votingId, cand1.address);

    let err;
    try {
      await votingSys.connect(p1).vote(votingId, cand2.address);
    } catch (error) {
      err = error;
    }
    expect(err).is.not.undefined;
  });

  async function checkCallByOwnerOnly(a) {
    let unexpectedError;
    try {
      
      await a(owner);
    } catch (error) {
      unexpectedError = error;
    }
    expect(unexpectedError).is.undefined;

    let expectedError;
    try {
      await a(p1);
    } catch (error) {
      expectedError = error;
    }
    expect(expectedError).is.not.undefined;
  }
});