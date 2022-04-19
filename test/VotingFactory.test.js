const { expect, assert } = require("chai");
const { BigNumber, FixedNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("VotingFactory", function () {
    let owner
    let cand1, cand2
    let p1, p2, p3
    let votingSys
    let voteFee = ethers.utils.parseEther("0.01")

    beforeEach(async function() {
        [owner, cand1, cand2, p1, p2, p3] = await ethers.getSigners();
        const VotingFactory = 
            await ethers.getContractFactory("VotingFactory", owner);
        votingSys = await VotingFactory.deploy();
        await votingSys.deployed();
    })

    it("should set duration only by owner", async function () {
        await checkCallByOwnerOnly(async function (sender) { 
            await votingSys.connect(sender).setDuration(5);
        });
    });

    it("should add a new voting only by owner", async function () {
        await checkCallByOwnerOnly(async function (sender) {
            await voting(sender, [cand1.address, cand2.address]);
            let v = await votingSys.getVotings();
            expect(v.length).eq(1);
        });
    });

    it("should require candidates for a new voting", async function () {
        await expect(voting(owner, [])).to.be.revertedWith(
            "at least 2 candidates expected"
        );
    });

    it("should be possible to have more than 1 voting", async function () {
        await voting(owner, [cand1.address, cand2.address]);
        await voting(owner, [cand1.address, cand2.address]);

        let v = await votingSys.getVotings();
        expect(v.length).eq(2);
    });

    it("should add a new vote from p1 for cand1", async function () {
        await voting(owner, [cand1.address, cand2.address]);
        let votingId = 0;
        const t = await vote(p1, cand1);

        let v = await votingSys.getVotingDetails(votingId);
        let votes = v[1];
        expect(votes.length).eq(1);
        expect(votes[0].owner).eq(p1.address);
        expect(votes[0].candidate).eq(cand1.address);
        await expect(() => t).changeEtherBalance(
            p1, 
            ethers.utils.parseEther("-0.01")
        );
    });

    it("shouldn't exceed vote limit from p1", async function () {
        await voting(owner, [cand1.address, cand2.address]);
        await vote(p1, cand1);

        await expect(vote(p1, cand2)).to.be.revertedWith(
            "Votes limit is exceeded"
        );
    });

    it("shouldn't vote for a non-existent candidate", async function () {
        await voting(owner, [cand1.address, cand2.address]);

        await expect(vote(p1, owner)).to.be.revertedWith(
            "no such candidate in the collection"
        );
    });

    it("shouldn't vote with a wrong price", async function () {
        await voting(owner, [cand1.address, cand2.address]);

        const wrongPrice = ethers.utils.parseEther("0.02")
        await expect(votingSys.connect(p1).vote(
            0, 
            cand1.address, 
            { value:wrongPrice }
        ))
        .to.be.revertedWith("Wrong value");
    });

    it("shouldn't finish before end date", async function () {
        await voting(owner, [cand1.address, cand2.address]);

        await expect(finish(owner)).to.be.revertedWith(
            "The voting can't be finished yet"
        );
    });

    it("shouldn't vote after end", async function () {
        this.timeout(2000);

        await votingSys.setDuration(1);
        await voting(owner, [cand1.address, cand2.address]);
        await delay(1000);

        await expect(vote(p1, cand1)).to.be.revertedWith(
            "Voting period ended"
        );
    });
    
    it("shouldn't fail when ask for non-existing voting", async function () {
        await expect(finish(owner)).to.be.revertedWith(
            "Voting doesn't exist"
        )
        await expect(vote(p1, cand1)).to.be.revertedWith(
            "Voting doesn't exist"
        )
        await expect(votingSys.withdraw(0)).to.be.revertedWith(
            "Voting doesn't exist"
        )
        await expect(votingSys.getVotingDetails(0)).to.be.revertedWith(
            "Voting doesn't exist"
        )
    });

    it("should finish simple voting and reward cand1", async function () {
        this.timeout(3000);
        
        await votingSys.setDuration(2);
        await voting(owner, [cand1.address, cand2.address]);
        await vote(p1, cand1);
        await delay(2000);
        const t = await finish(p2)

        await expect(() => t).to.changeEtherBalance(cand1, voteFee * 90/100)
        let v = await votingSys.getVotingDetails(0);
        expect(v[0].winner).eq(cand1.address);
        expect(v[0].state).eq(2);//finished
    });

    it("should finish complex voting and reward cand2", async function () {
        this.timeout(6000);

        await votingSys.setDuration(5);
        await voting(owner, [cand1.address, cand2.address, owner.address]);
        await vote(p1, cand1);
        await vote(p2, cand2);
        await vote(p3, cand2);
        await vote(owner, owner);
        await delay(5000);
        const t = await finish(p2)
        
        let expBalanceAfterVotes = 40000000000000000n;// ethers.utils.parseEther("0.04")
        await expect(() => t).to.changeEtherBalance(
            cand2, 
            expBalanceAfterVotes * 90n / 100n
        )

        let v = await votingSys.getVotingDetails(0);
        expect(v[0].winner).eq(cand2.address);
        expect(v[0].state).eq(2);//finished
    });

    it("shouldn't finish 2nd time", async function () {
        this.timeout(3000);

        await votingSys.setDuration(2);
        await voting(owner, [cand1.address, cand2.address]);
        await vote(p1, cand1);
        await delay(2000);
        await finish(p1)
        await expect(finish(owner)).to.be.revertedWith(
            "The voting finished already"
        )
    });

    it("should finish without the winner", async function () {
        this.timeout(5000);

        await votingSys.setDuration(4);
        await voting(owner, [cand1.address, cand2.address, owner.address]);
        await vote(p1, cand1);
        await vote(p2, cand2);
        await vote(p3, owner);
        await delay(4000);
        const t = await finish(p2)

        const refund = voteFee * 90 / 100
        await expect(() => t)
            .to.changeEtherBalances([p1, p2, p3], [refund, refund, refund])

        let v = await votingSys.getVotingDetails(0);
        expect(v[0].winner).eq(ethers.constants.AddressZero);
        expect(v[0].state).eq(2);//finished
    });

    it("should withdraw balance", async function () {
        this.timeout(3000);

        await votingSys.setDuration(2);
        await voting(owner, [cand1.address, cand2.address]);
        await vote(p1, cand1);
        await delay(2000);
        await finish(p2)
        
        const t = await votingSys.withdraw(0)

        await expect(() => t)
            .to.changeEtherBalance(owner, voteFee * 10 / 100)
    });

    it("shouldn't withdraw if voting isn't finished", async function () {
        await voting(owner, [cand1.address, cand2.address]);
        
        await expect(votingSys.withdraw(0))
            .to.be.revertedWith("Voting isn't finished yet")
    });

    async function timestamp(b) {
        return (await ethers.provider.getBlock(b)).timestamp;
    }

    function delay(ms) {
        return new Promise(r => setTimeout(r, ms));
    }

    async function checkCallByOwnerOnly(a) {
        let unexpectedError;
        try {
            await a(owner);
        } catch (error) {
            unexpectedError = error;
        }
        expect(unexpectedError).is.undefined;

        expect(a(p1)).to.be.reverted;
    }

    function finish(sender) {
        return votingSys.connect(sender).finish(0);
    }

    function voting(sender, cadidates) {
        return votingSys.connect(sender).addVoting(cadidates);
    }

    function vote(sender, voteFor) {
        return votingSys.connect(sender).vote(
            0, 
            voteFor.address, 
            { value: voteFee }
        );
    }
});