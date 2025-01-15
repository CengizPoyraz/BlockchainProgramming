import { expect } from 'chai';
import { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { Diamond, LotteryFacet, TestToken } from '../typechain-types';
import { getSelectors, FacetCutAction } from '../scripts/diamond';

describe('Lottery System', function() {
  let diamond: Diamond;
  let lottery: LotteryFacet;
  let token: TestToken;
  let owner: SignerWithAddress;
  let users: SignerWithAddress[];
  let lotteryEnd: number;

  beforeEach(async function() {
    [owner, ...users] = await ethers.getSigners();

    // Deploy Diamond with facets
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    const diamondCutFacet = await DiamondCutFacet.deploy();
    
    const Diamond = await ethers.getContractFactory('Diamond');
    diamond = await Diamond.deploy(owner.address, diamondCutFacet.address);

    // Deploy and add facets
    const FacetNames = [
      'DiamondLoupeFacet',
      'OwnershipFacet',
      'LotteryFacet'
    ];
    
    const cut = [];
    for (const FacetName of FacetNames) {
      const Facet = await ethers.getContractFactory(FacetName);
      const facet = await Facet.deploy();
      cut.push({
        facetAddress: facet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(facet)
      });
    }

    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.address);
    await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x');

    // Get lottery facet
    lottery = await ethers.getContractAt('LotteryFacet', diamond.address);

    // Deploy test token
    const Token = await ethers.getContractFactory('TestToken');
    token = await Token.deploy('Test Token', 'TST');
    await lottery.setPaymentToken(token.address);

    // Set up lottery end time
    lotteryEnd = (await time.latest()) + 86400; // 24 hours from now
  });

  describe('Lottery Creation', function() {
    it('Should create a new lottery with correct parameters', async function() {
      const tx = await lottery.createLottery(
        lotteryEnd,
        100, // noOfTickets
        5,   // noOfWinners
        50,  // minPercentage
        ethers.utils.parseEther('1'), // ticketPrice
        ethers.utils.formatBytes32String('hash'),
        'https://example.com'
      );

      const currentLotteryNo = await lottery.getCurrentLotteryNo();
      expect(currentLotteryNo).to.equal(1);

      const info = await lottery.getLotteryInfo(currentLotteryNo);
      expect(info.noOfTickets).to.equal(100);
      expect(info.noOfWinners).to.equal(5);
    });
  });

  describe('Ticket Purchase', function() {
    beforeEach(async function() {
      await lottery.createLottery(
        lotteryEnd,
        100,
        5,
        50,
        ethers.utils.parseEther('1'),
        ethers.utils.formatBytes32String('hash'),
        'https://example.com'
      );

      // Mint tokens to users
      for (const user of users.slice(0, 3)) {
        await token.mint(user.address, ethers.utils.parseEther('100'));
        await token.connect(user).approve(lottery.address, ethers.utils.parseEther('100'));
      }
    });

    it('Should allow users to buy tickets', async function() {
      const user = users[0];
      const quantity = 5;
      const randomNumber = ethers.utils.randomBytes(32);
      const hashedNumber = ethers.utils.keccak256(randomNumber);

      await lottery.connect(user).buyTicketTx(quantity, hashedNumber);

      const sales = await lottery.getLotterySales(1);
      expect(sales).to.equal(quantity);
    });

    it('Should not allow purchasing more than 30 tickets at once', async function() {
      const user = users[0];
      const quantity = 31;
      const randomNumber = ethers.utils.randomBytes(32);
      const hashedNumber = ethers.utils.keccak256(randomNumber);

      await expect(
        lottery.connect(user).buyTicketTx(quantity, hashedNumber)
      ).to.be.revertedWith('Invalid quantity');
    });
  });

  describe('Random Number Reveal', function() {
    beforeEach(async function() {
      await lottery.createLottery(
        lotteryEnd,
        100,
        5,
        50,
        ethers.utils.parseEther('1'),
        ethers.utils.formatBytes32String('hash'),
        'https://example.com'
      );

      // Mint tokens and approve
      await token.mint(users[0].address, ethers.utils.parseEther('100'));
      await token.connect(users[0]).approve(lottery.address, ethers.utils.parseEther('100'));
    });

    it('Should allow revealing random numbers during reveal phase', async function() {
      const user = users[0];
      const quantity = 5;
      const randomNumber = ethers.utils.randomBytes(32);
      const hashedNumber = ethers.utils.keccak256(randomNumber);

      // Buy tickets
      await lottery.connect(user).buyTicketTx(quantity, hashedNumber);

      // Move to reveal phase
      await time.increaseTo(lotteryEnd - 43200); // Move to halfway point

      // Reveal numbers
      await lottery.connect(user).revealRndNumberTx(0, quantity, randomNumber);

      // Check if numbers were revealed
      const tx = await lottery.getIthPurchasedTicketTx(0, 1);
      expect(tx.startTicketNo).to.equal(0);
      expect(tx.quantity).to.equal(quantity);
    });
  });

  describe('Lottery Completion', function() {
    beforeEach(async function() {
      await lottery.createLottery(
        lotteryEnd,
        100,
        5,
        50,
        ethers.utils.parseEther('1'),
        ethers.utils.formatBytes32String('hash'),
        'https://example.com'
      );

      // Setup users with tokens
      for (const user of users.slice(0, 3)) {
        await token.mint(user.address, ethers.utils.parseEther('100'));
        await token.connect(user).approve(lottery.address, ethers.utils.parseEther('100'));
      }
    });

    it('Should select winners correctly when lottery ends', async function() {
      // Buy tickets and reveal numbers
      for (let i = 0; i < 3; i++) {
        const randomNumber = ethers.utils.randomBytes(32);
        const hashedNumber = ethers.utils.keccak256(randomNumber);
        
        await lottery.connect(users[i]).buyTicketTx(10, hashedNumber);
        
        // Move to reveal phase
        if (i === 0) {
          await time.increaseTo(lotteryEnd - 43200);
        }
        
        await lottery.connect(users[i]).revealRndNumberTx(i * 10, 10, randomNumber);
      }

      // Move to end of lottery
      await time.increaseTo(lotteryEnd + 1);

      // Check winners
      const totalWinners = 5;
      for (let i = 0; i < totalWinners; i++) {
        const winningTicket = await lottery.getIthWinningTicket(1, i);
        expect(winningTicket).to.be.lte(29); // Should be within range of sold tickets
      }
    });
  });
});