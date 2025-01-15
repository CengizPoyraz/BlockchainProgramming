// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibLottery {
    bytes32 constant LOTTERY_STORAGE_POSITION = keccak256("diamond.standard.lottery.storage");
    
    struct Ticket {
        address owner;
        bytes32 hashRndNumber;
        bool revealed;
        uint256 rndNumber;
    }
    
    struct LotteryInfo {
        uint256 endTime;
        uint256 noOfTickets;
        uint256 noOfWinners;
        uint256 minPercentage;
        uint256 ticketPrice;
        bytes32 htmlHash;
        string url;
        uint256 ticketsSold;
        bool finished;
        mapping(uint256 => Ticket) tickets;
        mapping(uint256 => uint256) winningTickets;
        address paymentToken;
    }
    
    struct LotteryStorage {
        uint256 currentLotteryNo;
        mapping(uint256 => LotteryInfo) lotteries;
        mapping(uint256 => uint256[]) purchaseTxs;
    }
    
    function diamondStorage() internal pure returns (LotteryStorage storage ds) {
        bytes32 position = LOTTERY_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    
    function createLottery(
        uint256 unixEnd,
        uint256 noOfTickets,
        uint256 noOfWinners,
        uint256 minPercentage,
        uint256 ticketPrice,
        bytes32 htmlHash,
        string memory url
    ) internal returns (uint256) {
        require(unixEnd > block.timestamp, "Invalid end time");
        require(noOfTickets > 0, "Invalid ticket count");
        require(noOfWinners > 0 && noOfWinners <= noOfTickets, "Invalid winners count");
        require(minPercentage > 0 && minPercentage <= 100, "Invalid percentage");
        require(ticketPrice > 0, "Invalid ticket price");
        
        LotteryStorage storage ls = diamondStorage();
        ls.currentLotteryNo++;
        
        LotteryInfo storage newLottery = ls.lotteries[ls.currentLotteryNo];
        newLottery.endTime = unixEnd;
        newLottery.noOfTickets = noOfTickets;
        newLottery.noOfWinners = noOfWinners;
        newLottery.minPercentage = minPercentage;
        newLottery.ticketPrice = ticketPrice;
        newLottery.htmlHash = htmlHash;
        newLottery.url = url;
        
        return ls.currentLotteryNo;
    }
    
    function buyTickets(
        address buyer,
        uint256 quantity,
        bytes32 hashRndNumber
    ) internal returns (uint256) {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[ls.currentLotteryNo];
        
        require(block.timestamp < lottery.endTime - (lottery.endTime - block.timestamp) / 2, "Purchase phase ended");
        require(lottery.ticketsSold + quantity <= lottery.noOfTickets, "Not enough tickets available");
        
        uint256 totalCost = quantity * lottery.ticketPrice;
        IERC20(lottery.paymentToken).transferFrom(buyer, address(this), totalCost);
        
        uint256 startTicketNo = lottery.ticketsSold;
        for (uint256 i = 0; i < quantity; i++) {
            lottery.tickets[startTicketNo + i] = Ticket({
                owner: buyer,
                hashRndNumber: hashRndNumber,
                revealed: false,
                rndNumber: 0
            });
        }
        
        lottery.ticketsSold += quantity;
        ls.purchaseTxs[ls.currentLotteryNo].push(startTicketNo);
        ls.purchaseTxs[ls.currentLotteryNo].push(quantity);
        
        return startTicketNo;
    }
    
    function revealNumbers(
        address revealer,
        uint256 startTicketNo,
        uint256 quantity,
        uint256 rndNumber
    ) internal {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[ls.currentLotteryNo];
        
        require(block.timestamp >= lottery.endTime - (lottery.endTime - block.timestamp) / 2, "Reveal phase not started");
        require(block.timestamp < lottery.endTime, "Lottery ended");
        
        bytes32 hashRndNumber = keccak256(abi.encodePacked(rndNumber));
        
        for (uint256 i = 0; i < quantity; i++) {
            Ticket storage ticket = lottery.tickets[startTicketNo + i];
            require(ticket.owner == revealer, "Not ticket owner");
            require(!ticket.revealed, "Already revealed");
            require(ticket.hashRndNumber == hashRndNumber, "Invalid random number");
            
            ticket.revealed = true;
            ticket.rndNumber = rndNumber;
        }
        
        if (block.timestamp >= lottery.endTime && !lottery.finished) {
            finalizeLottery(ls.currentLotteryNo);
        }
    }
    
    function finalizeLottery(uint256 lotteryNo) internal {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[lotteryNo];
        
        require(!lottery.finished, "Already finalized");
        require(block.timestamp >= lottery.endTime, "Lottery not ended");
        
        lottery.finished = true;
        
        uint256 minTickets = (lottery.noOfTickets * lottery.minPercentage) / 100;
        if (lottery.ticketsSold < minTickets) {
            return; // Lottery canceled, refunds enabled
        }
        
        uint256 seed = 0;
        for (uint256 i = 0; i < lottery.ticketsSold; i++) {
            if (lottery.tickets[i].revealed) {
                seed ^= lottery.tickets[i].rndNumber;
            }
        }
        
        // Select winning tickets
        for (uint256 i = 0; i < lottery.noOfWinners; i++) {
            uint256 winningIndex = uint256(keccak256(abi.encodePacked(seed, i))) % lottery.ticketsSold;
            lottery.winningTickets[i] = winningIndex;
        }
    }
    
    function withdrawRefund(address user, uint256 lotteryNo, uint256 startTicketNo) internal {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[lotteryNo];
        
        require(lottery.finished, "Lottery not finished");
        require(lottery.ticketsSold * 100 < lottery.noOfTickets * lottery.minPercentage, "Not eligible for refund");
        
        Ticket storage ticket = lottery.tickets[startTicketNo];
        require(ticket.owner == user, "Not ticket owner");
        require(!ticket.revealed, "Already refunded");
        
        ticket.revealed = true; // Use revealed flag to track refunds
        IERC20(lottery.paymentToken).transfer(user, lottery.ticketPrice);
    }
    
    function withdrawProceeds(uint256 lotteryNo) internal {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[lotteryNo];
        
        require(lottery.finished, "Lottery not finished");
        require(lottery.ticketsSold * 100 >= lottery.noOfTickets * lottery.minPercentage, "Lottery cancelled");
        
        uint256 totalProceeds = lottery.ticketsSold * lottery.ticketPrice;
        IERC20(lottery.paymentToken).transfer(msg.sender, totalProceeds);
    }
    
    // View functions
    function getCurrentLotteryNo() internal view returns (uint256) {
        return diamondStorage().currentLotteryNo;
    }
    
    function getNumPurchaseTxs(uint256 lotteryNo) internal view returns (uint256) {
        return diamondStorage().purchaseTxs[lotteryNo].length / 2;
    }
    
    function getIthPurchasedTicketTx(uint256 i, uint256 lotteryNo)
        internal
        view
        returns (uint256 startTicketNo, uint256 quantity)
    {
        LotteryStorage storage ls = diamondStorage();
        require(i < ls.purchaseTxs[lotteryNo].length / 2, "Invalid index");
        
        startTicketNo = ls.purchaseTxs[lotteryNo][i * 2];
        quantity = ls.purchaseTxs[lotteryNo][i * 2 + 1];
    }
    
    function checkIfTicketWon(address owner, uint256 lotteryNo, uint256 ticketNo)
        internal
        view
        returns (bool)
    {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[lotteryNo];
        
        require(lottery.finished, "Lottery not finished");
        require(lottery.tickets[ticketNo].owner == owner, "Not ticket owner");
        
        for (uint256 i = 0; i < lottery.noOfWinners; i++) {
            if (lottery.winningTickets[i] == ticketNo) {
                return true;
            }
        }
        return false;
    }
    
    function getIthWinningTicket(uint256 lotteryNo, uint256 i)
        internal
        view
        returns (uint256)
    {
        LotteryStorage storage ls = diamondStorage();
        LotteryInfo storage lottery = ls.lotteries[lotteryNo];
        require(lottery.finished, "Lottery not finished");
        require(i < lottery.noOfWinners, "Invalid winner index");
        return lottery.winningTickets[i];
    }
    
    function setPaymentToken(address tokenAddr) internal {
        LotteryStorage storage ls = diamondStorage();
        ls.lotteries[ls.currentLotteryNo].paymentToken = tokenAddr;
    }
    
    function getPaymentToken(uint256 lotteryNo) internal view returns (address) {
        return diamondStorage().lotteries[lotteryNo].paymentToken;
    }
    
    function getLotteryInfo(uint256 lotteryNo)
        internal
        view
        returns (
            uint256 endTime,
            uint256 noOfTickets,
            uint256 noOfWinners,
            uint256 minPercentage,
            uint256 ticketPrice
        )
    {
        LotteryInfo storage lottery = diamondStorage().lotteries[lotteryNo];
        return (
            lottery.endTime,
            lottery.noOfTickets,
            lottery.noOfWinners,
            lottery.minPercentage,
            lottery.ticketPrice
        );
    }
    
    function getLotteryURL(uint256 lotteryNo)
        internal
        view
        returns (bytes32 htmlHash, string memory url)
    {
        LotteryInfo storage lottery = diamondStorage().lotteries[lotteryNo];
        return (lottery.htmlHash, lottery.url);
    }
    
    function getLotterySales(uint256 lotteryNo) internal view returns (uint256) {
        return diamondStorage().lotteries[lotteryNo].ticketsSold;
    }
}