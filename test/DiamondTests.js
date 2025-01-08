const { expect } = require("chai");
const { ethers } = require("hardhat");
const { getSelectors, FacetCutAction } = require('./utils/diamond.js');

describe("Lottery Diamond", function () {
  let diamondAddress;
  let diamondCutFacet;
  let diamondLoupeFacet;
  let lotteryCoreFacet;
  let lotteryViewFacet;
  let lotteryAdminFacet;
  let lotteryRevealFacet;
  let owner;
  let addr1;
  let addr2;
  let testToken;

  before(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy test ERC20 token
    const TestToken = await ethers.getContractFactory("TestToken");
    testToken = await TestToken.deploy("Test Token", "TEST");
    await testToken.deployed();

    // Deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    diamondCutFacet = await DiamondCutFacet.deploy();
    await diamondCutFacet.deployed();

    // Deploy Diamond
    const Diamond = await ethers.getContractFactory('LotteryDiamond');
    const diamond = await Diamond.deploy(owner.address);
    await diamond.deployed();
    diamondAddress = diamond.address;

    // Deploy facets
    const DiamondLoupeFacet = await ethers.getContractFactory('DiamondLoupeFacet');
    const LotteryCoreFacet = await ethers.getContractFactory('LotteryCoreFacet');
    const LotteryViewFacet = await ethers.getContractFactory('LotteryViewFacet');
    const LotteryAdminFacet = await ethers.getContractFactory('LotteryAdminFacet');
    const LotteryRevealFacet = await ethers.getContractFactory('LotteryRevealFacet');

    diamondLoupeFacet = await DiamondLoupeFacet.deploy();
    lotteryCoreFacet = await LotteryCoreFacet.deploy();
    lotteryViewFacet = await LotteryViewFacet.deploy();
    lotteryAdminFacet = await LotteryAdminFacet.deploy();
    lotteryRevealFacet = await LotteryRevealFacet.deploy();

    // Get facet cuts
    const cut = [
      {
        facetAddress: diamondLoupeFacet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(diamondLoupeFacet)
      },
      {
        facetAddress: lotteryCoreFacet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(lotteryCoreFacet)
      },
      {
        facetAddress: lotteryViewFacet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(lotteryViewFacet)
      },
      {
        facetAddress: lotteryAdminFacet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(lotteryAdminFacet)
      },
      {
        facetAddress: lotteryRevealFacet.address,
        action: FacetCutAction.Add,
        functionSelectors: getSelectors(lotteryRevealFacet)
      }
    ];

    // Attach facets to diamond
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamondAddress);
    await diamondCut.diamondCut(cut, ethers.constants.AddressZero, '0x');

    // Get facet instances
    lotteryCoreFacet = await ethers.getContractAt('LotteryCoreFacet', diamondAddress);
    lotteryViewFacet = await ethers.getContractAt('LotteryViewFacet', diamondAddress);
    lotteryAdminFacet = await ethers.getContractAt('LotteryAdminFacet', diamondAddress);
    lotteryRevealFacet = await ethers.getContractAt('LotteryRevealFacet', diamondAddress);
  });

  describe("Diamond Setup", function () {
    it("Should have all facets", async function () {
      const loupe = await ethers.getContractAt('IDiamondLoupe', diamondAddress);
      const facets = await loupe.facets();
      expect(facets.length).to.equal(6); // Including DiamondCutFacet
    });
  });

  describe("Lottery Creation", function () {
    it("Should allow owner to create a lottery", async function () {
      const endTime = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now
      
      await expect(lotteryCoreFacet.createLottery(
        endTime,
        100, // totalTickets
        5,   // winnersCount
        50,  // minTicketPercentage
        ethers.utils.parseEther("0.1"), // ticketPrice
        ethers.utils.id("description"), // lotteryDescHash
        "https://example.com" // lotteryDescUrl
      )).to.emit(lotteryCoreFacet, "LotteryCreated").withArgs(1);

      const currentLotteryNo = await lotteryViewFacet.getCurrentLotteryNo();
      expect(currentLotteryNo).to.equal(1);
    });

    it("Should not allow non-owner to create lottery", async function () {
      const endTime = Math.floor(Date.now() / 1000) + 86400;
      
      await expect(
        lotteryCoreFacet.connect(addr1).createLottery(
          endTime,
          100,
          5,
          50,
          ethers.utils.parseEther("0.1"),
          ethers.utils.id("description"),
          "https://example.com"
        )
      ).to.be.revertedWith("Not the owner");
    });
  });

  describe("Ticket Purchase", function () {
    before(async function () {
      // Set payment token
      await lotteryAdminFacet.setPaymentToken(testToken.address);
      
      // Mint some tokens to addr1
      await testToken.mint(addr1.address, ethers.utils.parseEther("10"));
      await testToken.connect(addr1).approve(diamondAddress, ethers.utils.parseEther("10"));
    });

    it("Should allow users to buy tickets", async function () {
      const randomNumber = ethers.utils.randomBytes(32);
      const commitment = ethers.utils.keccak256(randomNumber);
      
      await expect(
        lotteryCoreFacet.connect(addr1).buyTicketTx(1, 5, commitment)
      ).to.emit(lotteryCoreFacet, "TicketsPurchased")
        .withArgs(1, addr1.address, 5);

      const sales = await lotteryViewFacet.getLotterySales(1);
      expect(sales).to.equal(5);
    });

    it("Should not allow buying more than 30 tickets at once", async function () {
      const randomNumber = ethers.utils.randomBytes(32);
      const commitment = ethers.utils.keccak256(randomNumber);
      
      await expect(
        lotteryCoreFacet.connect(addr1).buyTicketTx(1, 31, commitment)
      ).to.be.revertedWith("Invalid ticket count");
    });
  });

  describe("Random Number Reveal", function () {
    it("Should allow revealing random number during reveal stage", async function () {
      // Fast forward to reveal stage
      const lotteryInfo = await lotteryViewFacet.getLotteryInfo(1);
      const halfDuration = (lotteryInfo[0].toNumber() - Math.floor(Date.now() / 1000)) / 2;
      await ethers.provider.send("evm_increaseTime", [halfDuration]);
      await ethers.provider.send("evm_mine");

      const randomNumber = ethers.utils.randomBytes(32);
      
      await expect(
        lotteryRevealFacet.connect(addr1).revealRndNumberTx(1, 0, 5, randomNumber)
      ).to.emit(lotteryRevealFacet, "RandomNumberRevealed")
        .withArgs(1, addr1.address);
    });

    it("Should not allow revealing twice", async function () {
      const randomNumber = ethers.utils.randomBytes(32);
      
      await expect(
        lotteryRevealFacet.connect(addr1).revealRndNumberTx(1, 0, 5, randomNumber)
      ).to.be.revertedWith("Already revealed");
    });
  });

  describe("Lottery Finalization", function () {
    before(async function () {
      // Fast forward to end
      const lotteryInfo = await lotteryViewFacet.getLotteryInfo(1);
      const timeToEnd = lotteryInfo[0].toNumber() - Math.floor(Date.now() / 1000) + 1;
      await ethers.provider.send("evm_increaseTime", [timeToEnd]);
      await ethers.provider.send("evm_mine");
    });

    it("Should allow owner to withdraw proceeds after finalization", async function () {
      const lotteryInfo = await lotteryViewFacet.getLotteryInfo(1);
      const totalProceeds = lotteryInfo[4].mul(5); // ticketPrice * number of tickets sold
      
      await expect(
        lotteryAdminFacet.withdrawTicketProceeds(1)
      ).to.changeTokenBalance(testToken, owner, totalProceeds);
    });
  });

  describe("View Functions", function () {
    it("Should return correct lottery information", async function () {
      const [endTime, totalTickets, winners, minPercentage, ticketPrice] = 
        await lotteryViewFacet.getLotteryInfo(1);
      
      expect(totalTickets).to.equal(100);
      expect(winners).to.equal(5);
      expect(minPercentage).to.equal(50);
      expect(ticketPrice).to.equal(ethers.utils.parseEther("0.1"));
    });

    it("Should return correct lottery URL info", async function () {
      const [hash, url] = await lotteryViewFacet.getLotteryURL(1);
      
      expect(hash).to.equal(ethers.utils.id("description"));
      expect(url).to.equal("https://example.com");
    });

    it("Should return correct sales information", async function () {
      const sales = await lotteryViewFacet.getLotterySales(1);
      expect(sales).to.equal(5);
    });
  });
});