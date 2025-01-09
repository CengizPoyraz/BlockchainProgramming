// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./LibLotteryStorage.sol";

contract LotteryViewFacet {
    using LibLotteryStorage for LibLotteryStorage.LotteryState;

    function getCurrentLotteryNo() external view returns (uint) {
        return LibLotteryStorage.diamondStorage().currentLotteryNo;
    }

    function getLotteryInfo(uint lottery_no) external view returns (
        uint unixend, 
        uint nooftickets, 
        uint noofwinners, 
        uint minpercentage, 
        uint ticketprice
    ) {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.Lottery storage lottery = ds.lotteries[lottery_no];
        
        return (
            lottery.endTime,
            lottery.totalTickets,
            lottery.winnersCount,
            lottery.minTicketPercentage,
            lottery.ticketPrice
        );
    }

    function getLotteryURL(uint lottery_no) external view returns(
        bytes32 htmlhash, 
        string memory url
    ) {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.Lottery storage lottery = ds.lotteries[lottery_no];
        
        return (lottery.lotteryDescHash, lottery.lotteryDescUrl);
    }

    function getLotterySales(uint lottery_no) external view returns(uint) {
        return LibLotteryStorage.diamondStorage().lotteries[lottery_no].purchasedTickets;
    }

    function getNumPurchaseTxs(uint lottery_no) external view returns(uint) {
        return LibLotteryStorage.diamondStorage().purchaseTxCount;
    }

    function checkIfMyTicketWon(uint lottery_no, uint ticket_no) external view returns (bool) {
        return this.checkIfAddrTicketWon(msg.sender, lottery_no, ticket_no);
    }

    function checkIfAddrTicketWon(
        address addr, 
        uint lottery_no, 
        uint ticket_no
    ) external view returns (bool) {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        address[] storage winners = ds.lotteryWinners[lottery_no];
        
        for (uint i = 0; i < winners.length; i++) {
            if (winners[i] == addr) return true;
        }
        return false;
    }
}