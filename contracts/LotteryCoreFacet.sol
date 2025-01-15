// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "./LibLotteryStorage.sol";
contract LotteryCoreFacet {
    using LibLotteryStorage for LibLotteryStorage.LotteryState;

    event LotteryCreated(uint indexed lotteryId);
    event TicketsPurchased(uint indexed lotteryId, address indexed buyer, uint ticketCount);
    event RandomNumberCommitted(uint indexed lotteryId, address indexed user, bytes32 committedNumber);
    event RandomNumberRevealed(uint indexed lotteryId, address indexed user);
    event LotteryFinalized(uint indexed lotteryId);
    event LotteryCanceled(uint indexed lotteryId);
    event WinnersDetermined(uint indexed lotteryId);
    event RefundClaimed(uint indexed lotteryId, address indexed user, uint amount);

    modifier onlyOwner() {
        require(msg.sender == LibLotteryStorage.diamondStorage().owner, "Not the owner");
        _;
    }

    enum LotteryStage {
        PurchaseStage,
        RevealStage,
        Finalized
    }

    function getCurrentStage(uint lotteryId) public view returns (LotteryStage) {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.Lottery storage lottery = ds.lotteries[lotteryId];
        
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

    function createLottery(
        uint unixend,
        uint nooftickets,
        uint noofwinners, 
        uint minpercentage,
        uint ticketprice,
        bytes32 htmlhash, 
        string memory url
    ) external onlyOwner returns(uint) {
        require(unixend > block.timestamp, "End time must be in future");
        require(noofwinners > 0 && noofwinners <= nooftickets, "Invalid winners count");
        require(minpercentage > 0 && minpercentage <= 100, "Invalid minimum percentage");

        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        ds.currentLotteryNo++;

        ds.lotteries[ds.currentLotteryNo] = LibLotteryStorage.Lottery({
            beginTime: block.timestamp,
            endTime: unixend,
            totalTickets: nooftickets,
            purchasedTickets: 0,
            winnersCount: noofwinners,
            minTicketPercentage: minpercentage,
            ticketPrice: ticketprice,
            lotteryDescHash: htmlhash,
            lotteryDescUrl: url,
            isCanceled: false,
            isFinalized: false
        });

        emit LotteryCreated(ds.currentLotteryNo);
        return ds.currentLotteryNo;
    }

    function buyTicketTx(
        uint lottery_no, 
        uint quantity, 
        bytes32 hash_rnd_number
    ) external returns(uint) {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.Lottery storage lottery = ds.lotteries[lottery_no];
        
        require(quantity > 0 && quantity <= 30, "Invalid ticket count");
        require(lottery.purchasedTickets + quantity <= lottery.totalTickets, "Exceeds total tickets");
        require(getCurrentStage(lottery_no) == LotteryStage.PurchaseStage, "Invalid stage");

        uint totalCost = quantity * lottery.ticketPrice;
        require(
            ds.paymentToken.transferFrom(msg.sender, address(this), totalCost),
            "Payment failed"
        );

        LibLotteryStorage.TicketInfo storage ticketInfo = ds.userTickets[lottery_no][msg.sender];
        ticketInfo.ticketCount += quantity;
        ticketInfo.committedRandomNumber = hash_rnd_number;

        lottery.purchasedTickets += quantity;

        ds.purchaseTxs[lottery_no][ds.purchaseTxCount] = msg.sender;
        ds.purchaseTxCount++;

        emit TicketsPurchased(lottery_no, msg.sender, quantity);
        return ds.purchaseTxCount - 1;
    }
}