const hre = require("hardhat");

async function main() {
  const PokerGame = await hre.ethers.getContractFactory("PokerGame");
  const pokerGame = await PokerGame.deploy();

  console.log("Deploying PokerGame...");
  await pokerGame.waitForDeployment();
  
  const address = await pokerGame.getAddress();
  console.log("PokerGame deployed to:", address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 