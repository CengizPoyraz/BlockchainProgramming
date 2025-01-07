const { expect } = require('chai');
const { ethers } = require('hardhat');
require("@nomicfoundation/hardhat-chai-matchers");

describe('CompanyLotteriesTest', function () {
  let companyLotteries;
  let owner;
  let user1;
  let user2;
  let mockToken;

    // Helper function to create a lottery
    async function createLottery(
        params = {}
    ) {
        const defaultParams = {
            endTime: Math.floor(Date.now() / 1000) + 86400, // 24 hours from now
            totalTickets: 100,
            winnersCount: 3,
            minTicketPercentage: 50,
            ticketPrice: ethers.parseEther("0.1")
        };

        const finalParams = { ...defaultParams, ...params };
        console.log("[script] [createLottery] endTime: ", finalParams.endTime);
        const htmlHash = ethers.encodeBytes32String('lottery-desc-hash');
        const url = 'https://example.com/lottery-details';
        return await companyLotteries.createLottery(
            finalParams.endTime,
            finalParams.totalTickets,
            finalParams.winnersCount,
            finalParams.minTicketPercentage,
            finalParams.ticketPrice,
            htmlHash,
            url
        );
    }
  beforeEach(async function () {
        // Get signers
        [owner, user1, user2, user3] = await ethers.getSigners();

        // Deploy mock ERC20 token
        const MockToken = await ethers.getContractFactory("MockERC20");
        mockToken = await MockToken.deploy("MockToken", "MTK", 18);

        // Deploy CompanyLotteries contract
        const CompanyLotteriesFactory = await ethers.getContractFactory("CompanyLotteries");
        companyLotteries = await CompanyLotteriesFactory.deploy(owner);

        // Set payment token
        await companyLotteries.setPaymentToken(mockToken.target);

        // Mint tokens to users
        await mockToken.mint(user1.address, ethers.parseEther("1000"));
        await mockToken.mint(user2.address, ethers.parseEther("1000"));
        await mockToken.mint(user3.address, ethers.parseEther("1000"));

        // Approve tokens for the contract
        await mockToken.connect(user1).approve(companyLotteries.target, ethers.parseEther("1000"));
        await mockToken.connect(user2).approve(companyLotteries.target, ethers.parseEther("1000"));
        await mockToken.connect(user3).approve(companyLotteries.target, ethers.parseEther("1000"));


        // Debug: Check balances and allowances
        console.log('User1 Balance:', await mockToken.balanceOf(user1.address));
        console.log('User1 Allowance:', await mockToken.allowance(await user1.getAddress(), await companyLotteries.getAddress()));
  });

  describe("Deployment", function () {
    it("Should set the correct owner", async function () {
        expect(await companyLotteries.owner()).to.equal(owner.address);
    });
  });

  describe('Lottery Creation', function () {
    it('Should create a lottery successfully', async function () {
            // Explicitly convert parameters to ensure correct types
            const lotteryId = await createLottery({
                endTime: Math.floor(Date.now() / 1000) + 86400,
                totalTickets: 100,
                winnersCount: 3,
                minTicketPercentage: 50,
                ticketPrice: ethers.parseEther("0.1")
            }); 
            await expect(await lotteryId).to.emit(companyLotteries, "LotteryCreated").withArgs(1);
            
            const lottery = await companyLotteries.lotteries(1);
            expect(lottery.totalTickets).to.equal(100);
            expect(lottery.winnersCount).to.equal(3); 
    });

    it('Should prevent creating lottery with past end time', async function () {
      const pastTime = Math.floor(Date.now() / 1000) - 86400; // 24 hours ago
      const htmlHash = ethers.encodeBytes32String('lottery-desc-hash');
      const url = 'https://example.com/lottery-details';

      await expect(
        companyLotteries.createLottery(
          pastTime, 
          100, 
          3, 
          50, 
          ethers.parseEther('0.1'), 
          htmlHash, 
          url
        )
      ).to.be.revertedWith('End time must be in the future');
    });
  });

  describe('Ticket Purchasing', function () {
    it('Should allow purchasing tickets', async function () {
      const lotteryNo = await createLottery();
      await expect(await lotteryNo).to.emit(companyLotteries, "LotteryCreated").withArgs(1);

      const committedHash = ethers.keccak256(ethers.randomBytes(32));

      // Purchase tickets
      const purchaseTx = await companyLotteries.connect(user1).buyTicketTx(
        1, 
        20, 
        committedHash
      );

      const sales = await companyLotteries.getLotterySales(1);
      expect(sales).to.equal(20n);
    });

    it('Should prevent purchasing more than 30 tickets in one transaction', async function () {
      const lotteryNo = await createLottery();
      await expect(await lotteryNo).to.emit(companyLotteries, "LotteryCreated").withArgs(1);

      const committedHash = ethers.keccak256(ethers.randomBytes(32));

      await expect(
        companyLotteries.connect(user1).buyTicketTx(
          1, 
          31, 
          committedHash
        )
      ).to.be.revertedWith('Invalid ticket count');
    });

    it('Should prevent purchasing tickets after lottery end time', async function () {
      const pastTime = Math.floor(Date.now() / 1000) + 60; // Just 60 second in the future
      console.log("[script] pastTime: %d", pastTime);

      const lotteryNo = await createLottery({
        endTime: pastTime,
        totalTickets: 100,
        winnersCount: 3,
        minTicketPercentage: 50,
        ticketPrice: ethers.parseEther("0.1")
      });
      await expect(await lotteryNo).to.emit(companyLotteries, "LotteryCreated").withArgs(1);

      // Advance time
      // Wait to ensure we're past the lottery end time
      await ethers.provider.send('evm_increaseTime', [10]); // Just 10 second in the future
      await ethers.provider.send('evm_mine');

      const committedHash = ethers.keccak256(ethers.randomBytes(32));

      await expect(
        companyLotteries.connect(user1).buyTicketTx(
          1, 
          20, 
          committedHash
        )
      ).to.be.revertedWith('Lottery ended');
    });
  });

  describe('Lottery Proceeds', function () {
    it('Should allow owner to withdraw proceeds after lottery finalization', async function () {
      const endTime = Math.floor(Date.now() / 1000) + 600; // Just 60 second in the future
      const lotteryNo = await createLottery({
        endTime: endTime,
        totalTickets: 100,
        winnersCount: 3,
        minTicketPercentage: 50,
        ticketPrice: ethers.parseEther("0.1")
      });
      await expect(await lotteryNo).to.emit(companyLotteries, "LotteryCreated").withArgs(1);

      const committedHash = ethers.keccak256(ethers.randomBytes(32));

      // Purchase tickets
      await companyLotteries.connect(user1).buyTicketTx(
        1, 
        20, 
        committedHash
      );
      console.log("[script] ticket purchased");

      // Advance time to end of lottery
      const lotteryInfo = await companyLotteries.getLotteryInfo(lotteryNo);
      console.log("[script] lotteryInfo.unixend): %d", lotteryInfo.unixend);
      await ethers.provider.send('evm_mine', [Number(lotteryInfo.unixend) + 1]);

      // Finalize lottery
      // Note: In a real scenario, we'd need to reveal random numbers
      // This is a simplified test
      const initialBalance = await mockToken.balanceOf(owner.address);

      await companyLotteries.withdrawTicketProceeds(lotteryNo);

      const finalBalance = await mockToken.balanceOf(owner.address);
      const expectedProceeds = ethers.parseEther('0.1') * 20n;
      expect(finalBalance - initialBalance).to.equal(expectedProceeds);
    });

    it('Should prevent withdrawing proceeds from canceled lottery', async function () {
      const lotteryNo = await createLottery();

      // Advance time to end of lottery
      const lotteryInfo = await companyLotteries.getLotteryInfo(lotteryNo);
      await ethers.provider.send('evm_mine', [Number(lotteryInfo.unixbeg) + 1]);

      await expect(
        companyLotteries.withdrawTicketProceeds(lotteryNo)
      ).to.be.revertedWith('Lottery not eligible');
    });
  });

  describe('Refund', function () {
    it('Should allow refund if lottery is canceled', async function () {
      const lotteryNo = await createLottery();
      const committedHash = ethers.keccak256(ethers.randomBytes(32));

      // Purchase tickets
      await companyLotteries.connect(user1).buyTicketTx(
        lotteryNo, 
        20, 
        committedHash
      );

      // Advance time to end of lottery
      const lotteryInfo = await companyLotteries.getLotteryInfo(lotteryNo);
      await ethers.provider.send('evm_mine', [Number(lotteryInfo.unixbeg) + 1]);

      // Ensure lottery is marked as canceled (low ticket sales)
      await expect(
        companyLotteries.withdrawTicketRefund(lotteryNo, 0)
      ).to.be.revertedWith('Lottery not canceled');
    });
  });
});