# votes-dapp

My test project to get the basic ideas about developing smart contracts 
and the related stuff.

Steps to start:
- use 'npm install' in your console to install all dependencies
- create your own .env file with your private keys (see .env.example)
- check the hardhat.config.js to see the configuration and 
how your private keys are used there

- local deployment:
--- use 'npx hardhat node --network hardhat' in you console #1 to start 
your local blockchain node.
--- use 'npx hardhat run .\scripts\deploy.js --network localhost' 
in your console #2 to deploy the contract using test account

- rinkeby test network deployment:
--- use 'npx hardhat run .\scripts\deploy.js --network rinkeby' in your console
to deploy the contract to the rinkeby test network using your own test account

This project demonstrates a basic Hardhat use case.

Try running some of the following tasks:

```shell
Common tasks:

  accounts      Prints the list of accounts
  check         Check whatever you need
  clean         Clears the cache and deletes all artifacts
  compile       Compiles the entire project, building all artifacts
  console       Opens a hardhat console
  coverage      Generates a code coverage report for tests
  flatten       Flattens and prints contracts and their dependencies
  help          Prints this message
  node          Starts a JSON-RPC server on top of Hardhat Network
  run           Runs a user-defined script after compiling the project
  test          Runs mocha tests
  verify        Verifies contract on Etherscan

Interaction with the contract:

  add-voting    Adds a new voting with candidates
  get-details   Shows details of a voting
  get-votings   Shows all votings
  finish-voting Finishes the voting and rewards its winner
  vote          Adds a vote from a voter for a candidate
  withdraw      Transfers gathered comission to the owner
```
