const { ethers } = require("hardhat");
const { getSelectors, FacetCutAction } = require("./libraries/diamond.js");

async function deployDiamond() {
  const accounts = await ethers.getSigners();
  const contractOwner = accounts[0];
  console.log("Deploying contracts with the account:", contractOwner.address);
  console.log("Account balance:", (await contractOwner.getBalance()).toString());

  // Deploy DiamondCutFacet
  const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.deployed();
  console.log("DiamondCutFacet deployed:", diamondCutFacet.address);

  // Deploy Diamond
  const Diamond = await ethers.getContractFactory("Diamond");
  const diamond = await Diamond.deploy(contractOwner.address, diamondCutFacet.address);
  await diamond.deployed();
  console.log("Diamond deployed:", diamond.address);

  // Deploy DiamondInit
  // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
  const DiamondInit = await ethers.getContractFactory("DiamondInit");
  const diamondInit = await DiamondInit.deploy();
  await diamondInit.deployed();
  console.log("DiamondInit deployed:", diamondInit.address);

  // Deploy facets
  console.log("");
  console.log("Deploying facets...");
  const FacetNames = [
    "DiamondLoupeFacet",
    "OwnershipFacet",
    "LotteryFacet"
  ];
  
  // The `cut` is an array of objects that contain the facet addresses and function selectors
  const cut = [];
  for (const FacetName of FacetNames) {
    const Facet = await ethers.getContractFactory(FacetName);
    const facet = await Facet.deploy();
    await facet.deployed();
    console.log(`${FacetName} deployed: ${facet.address}`);
    cut.push({
      facetAddress: facet.address,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet)
    });
  }

  // Create a function call to init the Diamond
  const diamondInit = await ethers.getContractAt('DiamondInit', diamondInit.address);
  let functionCall = diamondInit.interface.encodeFunctionData('init');
  
  // Upgrade diamond with facets
  console.log("");
  console.log("Diamond Cut:", cut);
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
  let tx;
  let receipt;

  // Call to init function
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
  console.log("Diamond cut tx: ", tx.hash);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error(`Diamond upgrade failed: ${tx.hash}`);
  }
  console.log("Completed diamond cut");

  // Deploy supporting contracts
  console.log("");
  console.log("Deploying supporting contracts...");

  // Deploy mock ERC20 token for testing
  const MockToken = await ethers.getContractFactory("MockToken");
  const mockToken = await MockToken.deploy("Mock USDT", "USDT", ethers.utils.parseEther("1000000"));
  await mockToken.deployed();
  console.log("Mock Token deployed:", mockToken.address);

  // Initialize the LotteryFacet
  const lotteryFacet = await ethers.getContractAt('LotteryFacet', diamond.address);
  tx = await lotteryFacet.setPaymentToken(mockToken.address);
  await tx.wait();
  console.log("Payment token set");

  // Final verification
  const loupe = await ethers.getContractAt('DiamondLoupeFacet', diamond.address);
  const facets = await loupe.facets();
  console.log("");
  console.log("Facets:");
  for (const facet of facets) {
    console.log(`${facet.facetAddress}: ${facet.functionSelectors.length} functions`);
  }

  // Return the deployed addresses
  return {
    diamond: diamond.address,
    mockToken: mockToken.address,
    facets: {
      diamondCut: diamondCutFacet.address,
      diamondInit: diamondInit.address,
      lotteryFacet: cut[2].facetAddress // LotteryFacet is the third facet deployed
    }
  };
}

// Diamond helper functions
function getSelectors(contract) {
  const signatures = Object.keys(contract.interface.functions);
  const selectors = signatures.reduce((acc, val) => {
    if (val !== 'init(bytes)') {
      acc.push(contract.interface.getSighash(val));
    }
    return acc;
  }, []);
  return selectors;
}

// Deploy everything
async function main() {
  try {
    // Get network
    const network = await ethers.provider.getNetwork();
    console.log("Deploying to network:", network.name);
    console.log("Network chain ID:", network.chainId);

    // Deploy all contracts
    const deployed = await deployDiamond();

    // Log all deployed addresses
    console.log("");
    console.log("Deployed addresses:");
    console.log("-".repeat(50));
    console.log("Diamond:", deployed.diamond);
    console.log("Mock Token:", deployed.mockToken);
    console.log("Diamond Cut Facet:", deployed.facets.diamondCut);
    console.log("Diamond Init:", deployed.facets.diamondInit);
    console.log("Lottery Facet:", deployed.facets.lotteryFacet);

    // Save deployment info to a file
    const fs = require('fs');
    const deployments = {
      network: network.name,
      chainId: network.chainId,
      timestamp: new Date().toISOString(),
      addresses: deployed
    };

    fs.writeFileSync(
      `deployments/${network.name}.json`,
      JSON.stringify(deployments, null, 2)
    );

    console.log("");
    console.log("Deployment info saved to:", `deployments/${network.name}.json`);

  } catch (error) {
    console.error("Error during deployment:");
    console.error(error);
    process.exit(1);
  }
}

// Support for running script directly or through hardhat
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = {
  deployDiamond,
  getSelectors
};
