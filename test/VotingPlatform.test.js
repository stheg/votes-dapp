const { expect, assert } = require("chai");
const { BigNumber, FixedNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("VotingPlatform", function() {
    let owner
    let cand1, cand2
    let p1, p2, p3
    let votingPlt
    let voteFee = ethers.utils.parseEther("0.01")

    beforeEach(async function() {
        [owner, cand1, cand2, p1, p2, p3] = await ethers.getSigners();
        const VotingPlatform = 
            await ethers.getContractFactory("VotingPlatform", owner);
        votingPlt = await VotingPlatform.deploy();
        await votingPlt.deployed();
    })

    it("should set duration only by owner", 
        () => checkCallByOwnerOnly(
            async (sender) => await votingPlt.connect(sender).SetDuration(5)
        )
    );

    it("should revert when ask for non-existent voting", async function () {
        checkVotingShouldExist(() => vote(p1, cand1));
        checkVotingShouldExist(() => votingPlt.Withdraw(0));
        checkVotingShouldExist(() => votingPlt.GetVotingDetails(0));
        checkVotingShouldExist(() => calcResults(owner));
        checkVotingShouldExist(() => updResults(owner, 0));
        checkVotingShouldExist(() => finish(p1));
    });

    async function checkVotingShouldExist(f) {
        await expect(f()).to.be.revertedWith(
            "Voting doesn't exist"
        )
    }

    describe("Adding a new voting", function() {
        it("should add a new voting only by owner", 
            () => checkCallByOwnerOnly(
                async (sender) => {
                    await voting(sender, [cand1.address, cand2.address]);
                    const vs = await votingPlt.GetVotings();
                    expect(vs.length).eq(1);
                    const v = vs[0];
                    expect(v.candidates[0]).eq(cand1.address);
                    expect(v.candidates[1]).eq(cand2.address);
                    expect(v.state).eq(0);
                }
            )
        );

        it("should require 2 candidates", async function () {
            await expect(voting(owner, [])).to.be.revertedWith(
                "needs candidates"
            );
        });

        it("should be possible to have more than 1 voting", async function () {
            await voting(owner, [cand1.address, cand2.address]);
            await voting(owner, [cand1.address, cand2.address]);

            let v = await votingPlt.GetVotings();
            expect(v.length).eq(2);
        });
    })

    describe("Adding a new vote from a voter", function() {
        it("should add a new vote from p1 for cand1", async function () {
            await voting(owner, [cand1.address, cand2.address]);
            let votingId = 0;
            const t = await vote(p1, cand1);

            let v = await votingPlt.GetVotingDetails(votingId);
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
                "Votes limit"
            );
        });

        it("shouldn't vote for a non-existent candidate", async function () {
            await voting(owner, [cand1.address, cand2.address]);

            await expect(vote(p1, owner)).to.be.revertedWith(
                "no such candidate"
            );
        });

        it("shouldn't vote with a wrong price", async function () {
            await voting(owner, [cand1.address, cand2.address]);

            const wrongPrice = ethers.utils.parseEther("0.002")
            await expect(votingPlt.connect(p1).AddVote(
                0, 
                cand1.address, 
                { value:wrongPrice }
            ))
            .to.be.revertedWith("Wrong price");
        });
    })

    describe("Finishing a voting", function() {
        it("shouldn't calc results before end date", async function () {
            await voting(owner, [cand1.address, cand2.address]);

            await expect(calcResults(owner)).to.be.revertedWith(
                "can't be finished yet"
            );
        });

        it("shouldn't update results until it expects changes", async () => {
            await voting(owner, [cand1.address, cand2.address]);

            await expect(updResults(owner, 0)).to.be.revertedWith(
                "voting doesn't expect updates"
            );
        });

        it("shouldn't finish until results are in place", async function () {
            await voting(owner, [cand1.address, cand2.address]);

            await expect(finish(owner)).to.be.revertedWith(
                "voting isn't ready to finish"
            );
        });

        it("shouldn't vote after end", async function () {
            let duration = 1;
            this.timeout((duration+1) * 1000);

            await votingPlt.SetDuration(1);
            await voting(owner, [cand1.address, cand2.address]);
            await delaySec(duration);

            await expect(vote(p1, cand1)).to.be.revertedWith(
                "Voting period ended"
            );
        });

        it("shouldn't update with wrong winner", async function () {
            let duration = 2;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address]);
            await vote(p1, cand1);
            await delaySec(duration);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            const vs = await votingPlt.GetVotings();
            expect(vs[0].state).eq(1);
            await expect(updResults(owner, 3))
                .to.be.revertedWith("winner is out of boundaries");
        });

        it("shouldn't calculate results 2nd time", async function () {
            let duration = 2;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address]);
            await vote(p1, cand1);
            await delaySec(duration);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            await expect(calcResults(p1))
                .to.be.revertedWith("calculation was already requested");
        });


        it("should finish simple voting and reward cand1", async function () {
            let duration = 2;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address]);
            await vote(p1, cand1);
            await delaySec(duration);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            const vs = await votingPlt.GetVotings();
            expect(vs[0].state).eq(1);
            const t = await updResults(owner, 0);
            //const t = await finish(p2);

            await expect(() => t)
                .to.changeEtherBalance(cand1, voteFee * 90/100);
            
            let v = await votingPlt.GetVotingDetails(0);
            expect(v[0].winner).eq(0);
            expect(v[0].state).eq(3);//finished
        });

        it("should finish complex voting and reward cand2", async function () {
            let duration = 5;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address, owner.address]);
            await vote(p1, cand1);
            await vote(p2, cand2);
            await vote(p3, cand2);
            await vote(owner, owner);
            await delaySec(duration);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            const vs = await votingPlt.GetVotings();
            expect(vs[0].state).eq(1);
            const t = await updResults(owner, 1);
            
            //const t = await finish(p2)
            
            // ethers.utils.parseEther("0.04")
            let expBalanceAfterVotes = 40000000000000000n;
            await expect(() => t).to.changeEtherBalance(
                cand2, 
                expBalanceAfterVotes * 90n / 100n
            )

            let v = await votingPlt.GetVotingDetails(0);
            expect(v[0].winner).eq(1);
            expect(v[0].state).eq(3);//finished
        });

        // it("shouldn't finish 2nd time", async function () {
        //     let duration = 2;
        //     this.timeout((duration + 1) * 1000);

        //     await votingPlt.SetDuration(duration);
        //     await voting(owner, [cand1.address, cand2.address]);
        //     await vote(p1, cand1);
        //     await delaySec(duration);
        //     await finish(p1)

        //     await expect(finish(owner)).to.be.revertedWith("finished already");
        // });

        // it("should finish with the first winner when there are 2 winners", async function () {
        //     let duration = 4;
        //     this.timeout((duration + 1) * 1000);

        //     await votingPlt.SetDuration(duration);
        //     await voting(owner, [cand1.address, cand2.address, owner.address]);
        //     await vote(p1, cand1);
        //     await vote(p2, cand2);
        //     await vote(p3, owner);
        //     await delaySec(duration);
        //     const t1 = await calcResults(p2);
        //     expect(t1[0].state).eq(1);
        //     const t = await updResults(p2, 0);
        //     //const t = await finish(p2)

        //     const refund = voteFee * 90 / 100
        //     await expect(() => t)
        //         .to.changeEtherBalances([p1, p2, p3], [refund, refund, refund])

        //     let v = await votingPlt.GetVotingDetails(0);
        //     expect(v[0].winner).eq(ethers.constants.AddressZero);
        //     expect(v[0].state).eq(2);//finished
        // });
    })

    describe("Withdrawing", function() {
        it("shouldn't withdraw if voting isn't finished", async function () {
            await voting(owner, [cand1.address, cand2.address]);

            await expect(votingPlt.Withdraw(0))
                .to.be.revertedWith("Voting isn't finished")
        });

        it("should does nothing during withdraw if nobody voted", async () => {
            let duration = 2;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address]);
            await delaySec(duration + 1);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            const vs = await votingPlt.GetVotings();
            expect(vs[0].state).eq(1);
            await updResults(owner, 0);
            //await finish(p2)

            const t = await votingPlt.Withdraw(0)

            await expect(() => t)
                .to.changeEtherBalance(owner, 0);
        });
        
        it("should change owner's balance", async function () {
            let duration = 2;
            this.timeout((duration + 1) * 1000);

            await votingPlt.SetDuration(duration);
            await voting(owner, [cand1.address, cand2.address]);
            await vote(p1, cand1);
            await delaySec(duration);
            await expect(calcResults(p2))
                .to.emit(votingPlt, "PendingForResults")
                .withArgs(0);
            const vs = await votingPlt.GetVotings();
            expect(vs[0].state).eq(1);
            await updResults(owner, 0);
            //await finish(p2)
            
            const t = await votingPlt.Withdraw(0)

            await expect(() => t)
                .to.changeEtherBalance(owner, voteFee * 10 / 100)
        });
    })

    function delaySec(s) {
        return new Promise(r => setTimeout(r, s*1000));
    }

    async function checkCallByOwnerOnly(a) {
        let unexpectedError;
        try {
            await a(owner);
        } catch (error) {
            unexpectedError = error;
        }
        expect(unexpectedError).is.undefined;

        await expect(a(p1)).to.be.reverted;
    }

    function voting(sender, cadidates) {
        return votingPlt.connect(sender).AddVoting(cadidates);
    }

    function vote(sender, voteFor) {
        return votingPlt.connect(sender).AddVote(
            0,
            voteFor.address,
            { value: voteFee }
        );
    }

    function calcResults(sender) {
        return votingPlt.connect(sender).CalculateResults(0);
    }

    function updResults(sender, winnerId) {
        return votingPlt.connect(sender).UpdateVotingResult(0, winnerId);
    }

    function finish(sender) {
        return votingPlt.connect(sender).Finish(0);
    }
});