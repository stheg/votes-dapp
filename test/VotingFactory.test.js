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
    expect(votingFactory.address).to.be.properAddress
  });

  it("should NOT add a new voting", async function () {
    let a = false;
    try {
      await votingFactory.addVoting([]);
    } catch (error) {
      a = true;
    }
    assert(a);
  });

  it("should add a new voting", async function () {
    await votingFactory.addVoting([cand1.address, cand2.address]);
    let v = await votingFactory.getVoting(0);

    // console.log("end date: " + new Date(v[0].endDate * 1000).toLocaleString());
    // console.log("winner: " + v[0].winner);
    // console.log("candidates: " + v[0].candidates);
    // console.log("votes number: " + v[1]);
    
    expect(v).is.not.undefined;
  });
});