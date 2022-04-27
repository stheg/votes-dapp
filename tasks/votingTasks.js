task("set-duration", "Sets how long all new votings will last")
    .addParam("vpa", "address of a voting platform")
    .addParam("seconds", "duration in seconds")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        await plt.SetDuration(args.seconds);
    }); 
    
task("add-voting", "Adds a new voting with candidates")
    .addParam("vpa", "address of a voting platform")
    .addOptionalParam("from", "address of the caller")
    .addOptionalVariadicPositionalParam("candidates", "list of candidates' addresses")
    .setAction(async function (args) {
        let caller = await getCaller(args.from);
        let candidates = await getCandidates(args.candidates);
        const plt = await initPlatform(args.vpa, caller);

        await plt.AddVoting(candidates);
    });

task("get-votings", "Shows all votings")
    .addParam("vpa", "address of a voting platform")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        const votings = await plt.GetVotings();
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
            const voting = await plt.GetVotingDetails(args.voting);
            
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
            const t = await plt.AddVote(
                args.voting, 
                candidate, 
                { value: hre.ethers.utils.parseEther("0.01") }
            );
            console.log("the vote is registered");
        } catch (err) {
            console.log(err.error ?? err);
        }
    });

task("finish-voting", "Finishes the voting and rewards the winner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args, hre) => {
        const caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);

        const [owner] = await hre.ethers.getSigners();
        //owner waits for the event and then will do calculations
        RunCalcHandlerAsync(plt, owner);
        
        try {
            const votingId = parseInt(args.voting);
            await plt.CalculateResults(votingId);
            //caller waits for the event and then will finish the voting
            await RunFinishHandlerAsync(plt, caller);

        } catch (err) {
            console.log(err.error ?? err);
        }
    });

task("withdraw", "Transfers gathered comission to the owner")
    .addParam("vpa", "address of a voting platform")
    .addParam("voting", "id of the voting")
    .addOptionalParam("from", "address of the caller")
    .setAction(async (args) => {
        let caller = await getCaller(args.from);
        const plt = await initPlatform(args.vpa, caller);
        
        try {
            const t = await plt.Withdraw(args.voting);
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
    //const status = (voting.state > 0) ? "Finished" : "In Process";
    const winner = (voting.state == 3) ? voting.candidates[voting.winner] : "-";

    console.log("voting description:");
    console.log("   end date: " + endDate)
    console.log("   candidates: " + voting.candidates);
    console.log("   status: %s", voting.state);
    console.log("   winner: " + winner);
}



/// caller waits for the event and then will finish the voting
async function RunFinishHandlerAsync(plt, caller) {
    let votingId = -1;
    plt.once("ReadyToFinish", (vId) => { votingId = vId });
    while (votingId < 0) {
        await delaySec(10);
        //console.log("###################################");
    }
    await plt.connect(caller).Finish(votingId);
}

/// owner waits for the event and then will do calculations
async function RunCalcHandlerAsync(plt, owner) {
    let votingId = -1;
    // use 'on' instead of 'once' + extra loop to handle all voting
    // otherwise this function should be called for eachvoting separately
    plt.once("PendingForResults", (vId) => { votingId = vId; });

    while (votingId < 0) {
        await delaySec(10);
        // console.log("---------------------------------------");
    }
    plt.removeAllListeners("PendingForResults");

    console.log("calculating results for the voting with index " + votingId);

    const v = await plt.connect(owner).GetVotingDetails(votingId);
    const winner = calculateResults(v[0], v[1]);
    console.log("the winner is a candidate with index " + winner);
    await plt.connect(owner).UpdateVotingResult(votingId, winner);
}

function calculateResults(voting, votes) {
    let maxVal = 0;
    let winnerIndex = 0;

    let votesFor = [];
    //init all candidates' votes numbers with Zeros (the order is important)
    voting.candidates.forEach(c => votesFor.push(0));
    console.log(votesFor);

    //in case of equal numbers the first candidates will be the winner
    //currently, it depends on the order of votes 
    //another option is to extend the Vote structure to keep the date and use it here 
    votes.forEach(vote => {
        const candIndex = voting.candidates.findIndex(c => c == vote.candidate);
        votesFor[candIndex]++;
        console.log(votesFor);
        //update the winner to avoid second for-loop
        if (votesFor[candIndex] > maxVal) {
            maxVal = votesFor[candIndex];
            winnerIndex = candIndex;
        }
    });

    return winnerIndex;
}

function delaySec(s) {
    return new Promise(r => setTimeout(r, s * 1000));
}
