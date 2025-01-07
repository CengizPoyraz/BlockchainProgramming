// scripts/deploy-diamond.js
const { ethers } = require("hardhat");

async function deployDiamond() {
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

    // Deploy facets
    const FacetNames = [
        'OwnershipFacet',
        'LotteryFacet',
        'LotteryStateFacet',
        'LotteryTicketFacet'
    ];
    
    const cut = [];
    for (const FacetName of FacetNames) {
        const Facet = await ethers.getContractFactory(FacetName);
        const facet = await Facet.deploy();
        await facet.deployed();
        console.log(`${FacetName} deployed: ${facet.address}`);

        cut.push({
            facetAddress: facet.address,
            action: 0, // Add
            functionSelectors: getSelectors(facet)
        });
    }

    // Cut facets
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
    const tx = await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x');
    await tx.wait();

    return diamond.address;
}

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

deployDiamond()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });