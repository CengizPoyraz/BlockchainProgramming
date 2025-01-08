// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { LibLottery } from "../libraries/LibLottery.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LotteryFacet {
    // Events
    event LotteryCreated(uint indexed lotteryId);
    event TicketsPurchased(uint indexed lotteryId, address indexed buyer, uint ticketCount);
    event RandomNumberCommitted(uint indexed lotteryId, address indexed user, bytes32 committedNumber);
    event RandomNumberRevealed(uint indexed lotteryId, address indexed user);
    event LotteryFinalized(uint indexed lotteryId);
    event LotteryCanceled(uint indexed lotteryId);
    event WinnersDetermined(uint indexed lotteryId);
    event RefundClaimed(uint indexed lotteryId, address indexed user, uint amount);

    // Enums
    enum LotteryStage {
        PurchaseStage,
        RevealStage,
        Finalized
    }

    // Modifiers
    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    // Core Functions
    function createLottery(
        uint unixend,
        uint nooftickets,
        uint noofwinners,
        uint minpercentage,
        uint ticketprice,
        bytes32 htmlhash,
        string memory url
    ) external onlyOwner returns (uint) {
        require(unixend > block.timestamp, "End time must be in future");
        require(noofwinners > 0 && noofwinners <= nooftickets, "Invalid winners count");
        require(minpercentage > 0 && minpercentage <= 100, "Invalid minimum percentage");

        uint lotteryId = LibLottery.createLottery(
            unixend,
            nooftickets,
            noofwinners,
            minpercentage,
            ticketprice,
            htmlhash,
            url
        );

        emit LotteryCreated(lotteryId);
        return lotteryId;
    }

    function buyTicketTx(
        uint lottery_no,
        uint quantity,
        bytes32 hash_rnd_number
    ) external returns (uint) {
        require(quantity > 0 && quantity <= 30, "Invalid ticket quantity");
        
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery storage lottery = ls.lotteries[lottery_no];
        
        require(!lottery.isCanceled, "Lottery is canceled");
        require(block.timestamp <= lottery.endTime, "Lottery ended");
        require(getCurrentStage(lottery_no) == LotteryStage.PurchaseStage, "Not in purchase stage");
        require(lottery.purchasedTickets + quantity <= lottery.totalTickets, "Exceeds total tickets");

        // Calculate total cost
        uint totalCost = quantity * lottery.ticketPrice;
        
        // Handle payment
        require(
            ls.paymentToken.transferFrom(msg.sender, address(this), totalCost),
            "Payment failed"
        );

        // Update ticket info
        LibLottery.TicketInfo storage ticketInfo = ls.userTickets[lottery_no][msg.sender];
        ticketInfo.ticketCount += quantity;
        ticketInfo.committedRandomNumber = hash_rnd_number;
        lottery.purchasedTickets += quantity;

        emit TicketsPurchased(lottery_no, msg.sender, quantity);
        return lottery.purchasedTickets;
    }

    function revealRndNumberTx(
        uint lottery_no,
        uint sticketno,
        uint quantity,
        uint rnd_number
    ) external {
        require(getCurrentStage(lottery_no) == LotteryStage.RevealStage, "Not in reveal stage");
        
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.TicketInfo storage ticketInfo = ls.userTickets[lottery_no][msg.sender];
        
        require(!ticketInfo.revealed, "Already revealed");
        require(
            keccak256(abi.encodePacked(rnd_number)) == ticketInfo.committedRandomNumber,
            "Invalid random number"
        );

        ticketInfo.revealed = true;
        emit RandomNumberRevealed(lottery_no, msg.sender);
    }

    // Admin Functions
    function finalizeLottery(uint lottery_no) external onlyOwner {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery storage lottery = ls.lotteries[lottery_no];
        
        require(!lottery.isFinalized && !lottery.isCanceled, "Invalid lottery state");
        require(block.timestamp > lottery.endTime, "Lottery not ended");
        
        // Check minimum participation requirement
        uint minRequired = (lottery.totalTickets * lottery.minTicketPercentage) / 100;
        if (lottery.purchasedTickets < minRequired) {
            lottery.isCanceled = true;
            emit LotteryCanceled(lottery_no);
            return;
        }

        // Determine winners logic would go here
        lottery.isFinalized = true;
        emit LotteryFinalized(lottery_no);
    }

    function cancelLottery(uint lottery_no) external onlyOwner {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery storage lottery = ls.lotteries[lottery_no];
        
        require(!lottery.isFinalized && !lottery.isCanceled, "Invalid lottery state");
        
        lottery.isCanceled = true;
        emit LotteryCanceled(lottery_no);
    }

    function withdrawProceeds(uint lottery_no) external onlyOwner {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery storage lottery = ls.lotteries[lottery_no];
        
        require(lottery.isFinalized && !lottery.isCanceled, "Cannot withdraw");
        
        uint amount = lottery.purchasedTickets * lottery.ticketPrice;
        require(ls.paymentToken.transfer(msg.sender, amount), "Transfer failed");
    }

    // View Functions
    function getCurrentStage(uint lottery_no) public view returns (LotteryStage) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery memory lottery = ls.lotteries[lottery_no];

        if (lottery.isCanceled || lottery.isFinalized) {
            return LotteryStage.Finalized;
        }

        uint halfDuration = (lottery.endTime - lottery.beginTime) / 2;
        uint purchaseStageEnd = lottery.endTime - halfDuration;

        if (block.timestamp <= purchaseStageEnd) {
            return LotteryStage.PurchaseStage;
        } else if (block.timestamp <= lottery.endTime) {
            return LotteryStage.RevealStage;
        }

        return LotteryStage.Finalized;
    }

    function getLotteryInfo(uint lottery_no) external view returns (
        uint unixend,
        uint nooftickets,
        uint noofwinners,
        uint minpercentage,
        uint ticketprice,
        uint purchasedTickets,
        bool isCanceled,
        bool isFinalized
    ) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery memory lottery = ls.lotteries[lottery_no];
        
        return (
            lottery.endTime,
            lottery.totalTickets,
            lottery.winnersCount,
            lottery.minTicketPercentage,
            lottery.ticketPrice,
            lottery.purchasedTickets,
            lottery.isCanceled,
            lottery.isFinalized
        );
    }

    function getLotteryURL(uint lottery_no) external view returns (
        bytes32 htmlhash,
        string memory url
    ) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.Lottery memory lottery = ls.lotteries[lottery_no];
        return (lottery.lotteryDescHash, lottery.lotteryDescUrl);
    }

    function getUserTickets(
        uint lottery_no,
        address user
    ) external view returns (
        uint ticketCount,
        bool revealed
    ) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        LibLottery.TicketInfo memory ticketInfo = ls.userTickets[lottery_no][user];
        return (ticketInfo.ticketCount, ticketInfo.revealed);
    }

    function getWinners(uint lottery_no) external view returns (address[] memory) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        return ls.lotteryWinners[lottery_no];
    }

    function getCurrentLotteryId() external view returns (uint) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        return ls.currentLotteryNo;
    }

    // Token Management
    function setPaymentToken(address token) external onlyOwner {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        ls.paymentToken = IERC20(token);
    }

    function getPaymentToken() external view returns (address) {
        LibLottery.LotteryStorage storage ls = LibLottery.lotteryStorage();
        return address(ls.paymentToken);
    }
}
