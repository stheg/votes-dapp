task("set-duration", "Sets how long all new votings will last")
    .addParam("vpa", "address of a voting platform")
    .addParam("seconds", "duration in seconds")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        const votings = await plt.setDuration(args.seconds);
        votings.forEach(v => formatVoting(v));
    }); 
    
    task("add-voting", "Adds a new voting with candidates")
    .addParam("vpa", "address of a voting platform")
    .addOptionalParam("from", "address of the caller")
    .addOptionalVariadicPositionalParam("candidates", "list of candidates' addresses")
    .setAction(async function (args) {
        let caller = await getCaller(args.from);
        let candidates = await getCandidates(args.candidates);
        const plt = await initPlatform(args.vpa, caller);

        await plt.addVoting(candidates);
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
        try {
            const voting = await plt.getVotingDetails(args.voting);
            
            formatVoting(voting[0]);
            console.log("registered %s votes: ", voting[1].length);
            voting[1].forEach(vote => {
                console.log("   voter: " + vote.owner);
                console.log("   candidate: " + vote.candidate);
                console.log("----------------------------");
            });
        } catch (err) {
            console.log(err.error ?? err);
        }
    });

task("vote", "Adds a vote from the voter for the candidate")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("candidate", "address of the candidate")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        let candidate = args.candidate ?? caller.address;
        const plt = await initPlatform(args.vpa, caller);
        
        try {
            const t = await plt.vote(
                args.voting, 
                candidate, 
                { value: hre.ethers.utils.parseEther("0.01") }
            );
            console.log("the vote is registered");
        } catch (err) {
            console.log(err.error ?? err);
        }
    });

task("finish-voting", "finishes the voting and rewards the winner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        try {
            const t = await plt.finish(args.voting);
        } catch (err) {
            console.log(err.error ?? err);
        }
    });

task("withdraw", "transfers gathered comission to the owner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        try {
            const t = await plt.withdraw(args.voting);
        } catch (err) {
            console.log(err.error ?? err);
        }
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

async function getCandidates(arg) {
    let cands;
    if (arg != undefined && arg != []) {
        cands = arg;
    } else {
        [acc1, acc2] = await hre.ethers.getSigners();
        cands = [acc1.address, acc2.address]
    }
    return cands;
}

function formatVoting(voting) {
    const endDate = new Date(voting.endDate * 1000).toLocaleDateString();
    const status = (voting.state > 0) ? "Finished" : "In Process";
    const winner = (voting.state > 0) ? voting.candidates[voting.winner] : "-";

    console.log("voting description:");
    console.log("   end date: " + endDate)
    console.log("   candidates: " + voting.candidates);
    console.log("   status: %s", status);
    console.log("   winner: " + winner);
}