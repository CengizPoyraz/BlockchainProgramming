import { ethers } from 'hardhat';
import { getSelectors, FacetCutAction } from './libraries/diamond';

async function main() {
  const accounts = await ethers.getSigners();
  const contractOwner = accounts[0];

  // Deploy DiamondCutFacet
  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.deployed();
  console.log('DiamondCutFacet deployed:', diamondCutFacet.address);

  // Deploy Diamond
  const Diamond = await ethers.getContractFactory('Diamond');
  const diamond = await Diamond.deploy(contractOwner.address, diamondCutFacet.address);
  await diamond.deployed();
  console.log('Diamond deployed:', diamond.address);

  // Deploy DiamondInit
  // DiamondInit provides a function that is called when the diamond is upgraded to initialize state variables
  const DiamondInit = await ethers.getContractFactory('DiamondInit');
  const diamondInit = await DiamondInit.deploy();
  await diamondInit.deployed();
  console.log('DiamondInit deployed:', diamondInit.address);

  // Deploy facets
  console.log('');
  console.log('Deploying facets');
  const FacetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'LotteryFacet'
  ];
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

  // Upgrade diamond with facets
  console.log('');
  console.log('Diamond Cut:', cut);
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
  let tx;
  let receipt;

  // Call to init function
  let functionCall = diamondInit.interface.encodeFunctionData('init');
  tx = await diamondCut.diamondCut(cut, diamondInit.address, functionCall);
  receipt = await tx.wait();
  if (!receipt.status) {
    throw Error('Diamond upgrade failed: ' + tx.hash);
  }
  console.log('Diamond cut complete');

  // Deploy ERC20 token for testing
  const Token = await ethers.getContractFactory('TestToken');
  const token = await Token.deploy('Lottery Token', 'LTK');
  await token.deployed();
  console.log('Test Token deployed:', token.address);

  // Set token address in lottery
  const lottery = await ethers.getContractAt('LotteryFacet', diamond.address);
  tx = await lottery.setPaymentToken(token.address);
  await tx.wait();
  console.log('Payment token set');

  return {
    diamond: diamond.address,
    token: token.address,
    facets: {
      diamondCut: diamondCutFacet.address,
      diamondInit: diamondInit.address
    }
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });