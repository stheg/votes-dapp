const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

describe("VotingFactory", function () {
  let owner
  let cand1, cand2
  let p1, p2, p3
  let votingFactory

  beforeEach(async function() {
    [owner, cand1, cand2, p1, p2, p3] = await ethers.getSigners();
    const VotingFactory = 
      await ethers.getContractFactory("VotingFactory", owner);
    votingFactory = await VotingFactory.deploy();
    await votingFactory.deployed();
  })
  
  it("should be deployed", async function () {
    expect(votingFactory.address).is.properAddress;
  });

  it("should NOT add a new voting without candidates", async function () {
    let err;
    try {
      await votingFactory.addVoting([]);
    } catch (error) {
      err = error;
    }
    expect(err).is.not.undefined;
  });

  it("should be possible to add a new voting only by owner", async function () {
    let err;
    try {
      await votingFactory.connect(p1).addVoting([cand1.address]);
    } catch (error) {
      err = error;
    }
    expect(err).is.not.undefined;
  });

  it("should add a new voting", async function () {
    await votingFactory.addVoting([cand1.address, cand2.address]);
    let v = await votingFactory.getVotings();
    expect(v.length).eq(1);
  });

  it("should be possible to have more than 1 voting", async function () {
    await votingFactory.addVoting([cand1.address, cand2.address]);
    await votingFactory.addVoting([cand1.address, cand2.address]);

    let v = await votingFactory.getVotings();
    expect(v.length).eq(2);
  });
 
  it("should add a new vote from p1 for cand1", async function () {
    await votingFactory.addVoting([cand1.address, cand2.address]);
    let votingId = 0;
    await votingFactory.connect(p1).vote(votingId, cand1.address);

    let v = await votingFactory.getVotingDetails(0);
    expect(v[1].length).eq(1);
  });

  it("should NOT add a second vote from p1", async function () {
    await votingFactory.addVoting([cand1.address, cand2.address]);
    let votingId = 0;
    await votingFactory.connect(p1).vote(votingId, cand1.address);

    let err;
    try {
      await votingFactory.connect(p1).vote(votingId, cand2.address);
    } catch (error) {
      err = error;
    }
    expect(err).is.not.undefined;
  });
});