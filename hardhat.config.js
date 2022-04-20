const { task, subtask, types } = require("hardhat/config");

require("@nomiclabs/hardhat-waffle");
require("solidity-coverage");
require("dotenv").config();

const platformArtifact = require(
  "./artifacts/contracts/VotingPlatform.sol/VotingPlatform.json"
);

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address, await account.getBalance());
  }
});

task("addVoting", "Adds a new voting with candidates")
  .addParam("vpa", "address of a voting platform")
  .addVariadicPositionalParam("candidates", "list of candidates' addresses")
  .setAction(async function(args, hre) {
    const [acc1] = await hre.ethers.getSigners();
    const plt = new hre.ethers.Contract(
      args.vpa, 
      platformArtifact.abi, 
      acc1
    );
    await plt.addVoting(args.candidates);
  });

task("getVotings", "Shows all votings")
  .addParam("vpa", "address of a voting platform")
  .setAction(async (args, hre) => {
    const [acc1] = await hre.ethers.getSigners();
    const plt = new hre.ethers.Contract(
      args.vpa,
      platformArtifact.abi,
      acc1
    );
    const votings = await plt.getVotings();
    votings.forEach(v => formatVoting(v));
  });

task("getDetails", "Shows details of the voting")
  .addParam("vpa", "address of a voting platform")
  .addParam("id", "voting's id")
  .setAction(async (args, hre) => {
    const [acc1] = await hre.ethers.getSigners();
    const plt = new hre.ethers.Contract(
      args.vpa,
      platformArtifact.abi,
      acc1
    );
    const voting = await plt.getVotingDetails(args.id);
    
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
  .setAction(async (args, hre) => {
    const [acc1] = await hre.ethers.getSigners();
    const price = await hre.ethers.utils.parseUnits("0.01", "ether");
    const plt = new hre.ethers.Contract(
      args.vpa,
      platformArtifact.abi,
      acc1
    );
    await plt.vote(
      args.id,
      args.candidate,
      { value: price }
    );

    console.log("the vote is registered");
  });

task("finishVoting", "finishes the voting and rewards the winner")
  .addParam("vpa", "address of a voting platform")
  .addParam("id", "voting's id")
  .setAction(async (args, hre) => {
    const [acc1] = await hre.ethers.getSigners();
    const plt = new hre.ethers.Contract(
      args.vpa,
      platformArtifact.abi,
      acc1
    );
    await plt.finish(args.id);
  });

task("withdraw", "transfers gathered comission to the owner")
  .addParam("vpa", "address of a voting platform")
  .addParam("id", "voting's id")
  .setAction(async (args, hre) => {
    const [acc1] = await hre.ethers.getSigners();
    const plt = new hre.ethers.Contract(
      args.vpa,
      platformArtifact.abi,
      acc1
    );
    await plt.withdraw(args.id);
  });

function formatVoting(voting) {
  const startDate = new Date(voting.startDate * 1000).toDateString();
  const endDate = new Date(voting.endDate * 1000).toDateString();
  const status = (voting.state > 0) ? "Finished" : "In Process";

  console.log("voting description:");        
  console.log("   start date: " + startDate)
  console.log("   end date: " + endDate)
  console.log("   candidates: " + voting.candidates);
  console.log("   status: %s", status);
  console.log("   winner: " + voting.winner);
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: "0.8.13",
    networks: {
        rinkeby: {
            url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALC_KEY}`,
            accounts: [process.env.ACC_1, process.env.ACC_2]
        },
        hardhat: {
          chainId: 1337
        }
    }
};
