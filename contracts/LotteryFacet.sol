// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/LibDiamond.sol";
import "../libraries/LibLottery.sol";

contract LotteryFacet {
    event LotteryCreated(uint256 indexed lotteryNo, uint256 endTime, uint256 ticketPrice);
    event TicketsPurchased(uint256 indexed lotteryNo, address buyer, uint256 startTicketNo, uint256 quantity);
    event NumberRevealed(uint256 indexed lotteryNo, uint256 startTicketNo, uint256 quantity);
    
    function createLottery(
        uint256 unixEnd,
        uint256 noOfTickets,
        uint256 noOfWinners,
        uint256 minPercentage,
        uint256 ticketPrice,
        bytes32 htmlHash,
        string memory url
    ) external returns (uint256) {
        LibDiamond.enforceIsContractOwner();
        return LibLottery.createLottery(
            unixEnd,
            noOfTickets,
            noOfWinners,
            minPercentage,
            ticketPrice,
            htmlHash,
            url
        );
    }
    
    function buyTicketTx(uint256 quantity, bytes32 hashRndNumber) external returns (uint256) {
        require(quantity > 0 && quantity <= 30, "Invalid quantity");
        return LibLottery.buyTickets(msg.sender, quantity, hashRndNumber);
    }
    
    function revealRndNumberTx(
        uint256 startTicketNo,
        uint256 quantity,
        uint256 rndNumber
    ) external {
        LibLottery.revealNumbers(msg.sender, startTicketNo, quantity, rndNumber);
    }
    
    function getNumPurchaseTxs(uint256 lotteryNo) external view returns (uint256) {
        return LibLottery.getNumPurchaseTxs(lotteryNo);
    }
    
    function getIthPurchasedTicketTx(uint256 i, uint256 lotteryNo)
        external
        view
        returns (uint256 startTicketNo, uint256 quantity)
    {
        return LibLottery.getIthPurchasedTicketTx(i, lotteryNo);
    }
    
    function checkIfMyTicketWon(uint256 lotteryNo, uint256 ticketNo)
        external
        view
        returns (bool)
    {
        return LibLottery.checkIfTicketWon(msg.sender, lotteryNo, ticketNo);
    }
    
    function checkIfAddrTicketWon(
        address addr,
        uint256 lotteryNo,
        uint256 ticketNo
    ) external view returns (bool) {
        return LibLottery.checkIfTicketWon(addr, lotteryNo, ticketNo);
    }
    
    function getIthWinningTicket(uint256 lotteryNo, uint256 i)
        external
        view
        returns (uint256)
    {
        return LibLottery.getIthWinningTicket(lotteryNo, i);
    }
    
    function withdrawTicketRefund(uint256 lotteryNo, uint256 startTicketNo)
        external
    {
        LibLottery.withdrawRefund(msg.sender, lotteryNo, startTicketNo);
    }
    
    function getCurrentLotteryNo() external view returns (uint256) {
        return LibLottery.getCurrentLotteryNo();
    }
    
    function withdrawTicketProceeds(uint256 lotteryNo) external {
        LibDiamond.enforceIsContractOwner();
        LibLottery.withdrawProceeds(lotteryNo);
    }
    
    function setPaymentToken(address tokenAddr) external {
        LibDiamond.enforceIsContractOwner();
        LibLottery.setPaymentToken(tokenAddr);
    }
    
    function getPaymentToken(uint256 lotteryNo)
        external
        view
        returns (address)
    {
        return LibLottery.getPaymentToken(lotteryNo);
    }
    
    function getLotteryInfo(uint256 lotteryNo)
        external
        view
        returns (
            uint256 unixEnd,
            uint256 noOfTickets,
            uint256 noOfWinners,
            uint256 minPercentage,
            uint256 ticketPrice
        )
    {
        return LibLottery.getLotteryInfo(lotteryNo);
    }
    
    function getLotteryURL(uint256 lotteryNo)
        external
        view
        returns (bytes32 htmlHash, string memory url)
    {
        return LibLottery.getLotteryURL(lotteryNo);
    }
    
    function getLotterySales(uint256 lotteryNo)
        external
        view
        returns (uint256)
    {
        return LibLottery.getLotterySales(lotteryNo);
    }
}