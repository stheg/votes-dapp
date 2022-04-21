task("add-voting", "Adds a new voting with candidates")
    .addParam("vpa", "address of a voting platform")
    .addOptionalParam("from", "address of the caller")
    .addOptionalVariadicPositionalParam("candidates", "list of candidates' addresses")
    .setAction(async function (args) {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        await plt.addVoting(args.candidates);
    });

task("get-votings", "Shows all votings")
    .addParam("vpa", "address of a voting platform")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        const votings = await plt.getVotings();
        votings.forEach(v => formatVoting(v));
    });

task("get-details", "Shows details of the voting")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        const voting = await plt.getVotingDetails(args.voting);
        
        formatVoting(voting[0]);
        console.log("registered %s votes: ", voting[1].length);
        voting[1].forEach(vote => {
            console.log("   voter: " + vote.owner);
            console.log("   candidate: " + vote.candidate);
            console.log("----------------------------");
        });
    });

task("vote", "Adds a vote from the voter for the candidate")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addParam("candidate", "address of the candidate")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        try {
            await plt.vote(
                args.voting, 
                args.candidate, 
                { value: hre.ethers.utils.parseEther("0.01") }
            );
        } catch (err) {
            console.log(err);
        }
        console.log("the vote is registered");
    });

task("finish-voting", "finishes the voting and rewards the winner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        await plt.finish(args.voting);
    });

task("withdraw", "transfers gathered comission to the owner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        await plt.withdraw(args.voting);
    });

async function initPlatform(address, acc) {
    const VotingPlatform = await hre.ethers.getContractFactory("VotingPlatform");
    const plt = await new hre.ethers.Contract(address, VotingPlatform.interface, acc);
    return plt;
}

async function getCaller(addr) {
    let acc;
    if (addr != undefined) {
        acc = await hre.ethers.getSigner(addr);
    } else {
        [acc] = await hre.ethers.getSigners();
    }
    return acc;
}

function formatVoting(voting) {
    const startDate = new Date(voting.startDate * 1000).toLocaleDateString();
    const endDate = new Date(voting.endDate * 1000).toLocaleDateString();
    const status = (voting.state > 0) ? "Finished" : "In Process";

    console.log("voting description:");
    console.log("   start date: " + startDate)
    console.log("   end date: " + endDate)
    console.log("   candidates: " + voting.candidates);
    console.log("   status: %s", status);
    console.log("   winner: " + voting.winner);
}