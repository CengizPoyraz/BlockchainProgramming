// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LibLotteryStorage.sol";

contract LotteryAdminFacet {
    using LibLotteryStorage for LibLotteryStorage.LotteryState;

    modifier onlyOwner() {
        require(msg.sender == LibLotteryStorage.diamondStorage().owner, "Not the owner");
        _;
    }

    function setPaymentToken(address erctokenaddr) external onlyOwner {
        LibLotteryStorage.diamondStorage().paymentToken = IERC20(erctokenaddr);
    }

    function withdrawTicketProceeds(uint lottery_no) external onlyOwner {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.Lottery storage lottery = ds.lotteries[lottery_no];
        
        require(lottery.isFinalized && !lottery.isCanceled, "Lottery not eligible");

        uint totalProceeds = lottery.purchasedTickets * lottery.ticketPrice;
        require(
            ds.paymentToken.transfer(ds.owner, totalProceeds),
            "Proceeds transfer failed"
        );
    }
}