const { ethers } = require("hardhat");

async function main() {
  const EthGrowDAO = await ethers.getContractFactory("EthGrowDAO");
  const ethGrowDAO = await EthGrowDAO.deploy();

  await ethGrowDAO.deployed();

  console.log("EthGrowDAO contract deployed to:", ethGrowDAO.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
