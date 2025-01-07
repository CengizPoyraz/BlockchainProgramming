// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./diamond/Diamond.sol";

contract CompanyLotteries is Diamond {
    // Owner of the contract
    address public owner;

    // Lottery Struct to store all lottery details
    struct Lottery {
        uint beginTime;             // Unix timestamp for lottery start
        uint endTime;              // Unix timestamp for lottery end
        uint totalTickets;          // Total number of tickets issued
        uint purchasedTickets;      // Number of tickets purchased
        uint winnersCount;          // Number of winners
        uint minTicketPercentage;   // Minimum ticket percentage to run lottery
        uint ticketPrice;           // Price of each ticket
        bytes32 lotteryDescHash;       // Hash of lottery description HTML
        string lotteryDescUrl;         // URL of lottery description
        bool isCanceled;               // Flag to indicate if lottery is canceled
        bool isFinalized;              // Flag to indicate if lottery is finalized
    }

    // User ticket information
    struct TicketInfo {
        uint ticketCount;           // Number of tickets purchased
        bytes32 committedRandomNumber; // Committed random number
        bool revealed;                 // Whether random number was revealed
    }

    // Mapping to store lotteries
    mapping(uint => Lottery) public lotteries;
    
    // Mapping to track user tickets per lottery
    mapping(uint => mapping(address => TicketInfo)) public userTickets;
    
    // Mapping to store winners of each lottery
    mapping(uint => address[]) public lotteryWinners;

    // Current lottery number
    uint public currentLotteryNo;

    // Mapping to track purchase transactions
    mapping(uint => mapping(uint => address)) public purchaseTxs;
    uint public purchaseTxCount;

    // Payment token 
    IERC20 public paymentToken;

    event LotteryCreated(uint indexed lotteryId);
    event TicketsPurchased(uint indexed lotteryId, address indexed buyer, uint ticketCount);
    event RandomNumberCommitted(uint indexed lotteryId, address indexed user, bytes32 committedNumber);
    event RandomNumberRevealed(uint indexed lotteryId, address indexed user);
    event LotteryFinalized(uint indexed lotteryId);
    event LotteryCanceled(uint indexed lotteryId);
    event WinnersDetermined(uint indexed lotteryId);
    event RefundClaimed(uint indexed lotteryId, address indexed user, uint amount);

    // Constructor to set the owner
    constructor() {
        owner = msg.sender;
    }
    constructor(
        address _contractOwner, 
        address _diamondCutFacet
        ) payable Diamond(_contractOwner, _diamondCutFacet){

        }

    // Modifier to restrict access to owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }


    // Lottery stages
    enum LotteryStage {
        PurchaseStage,
        RevealStage,
        Finalized
    }

    function getCurrentStage(uint lotteryId) public view returns (LotteryStage) {
        Lottery memory lottery = lotteries[lotteryId];
        console.log("[contract] [getCurrentStage] lotteryId: %d isCancelled: %d isFinalized: %d", lotteryId, lottery.isCanceled, lottery.isFinalized);
        if (lottery.isCanceled || lottery.isFinalized) {
            return LotteryStage.Finalized;
        }

        uint halfDuration = (lottery.endTime - lottery.beginTime) / 2;
        uint purchaseStageEnd = lottery.endTime - halfDuration;

        console.log("[contract] [getCurrentStage] lotteryId: %d halfDuration: %d purchaseStageEnd: %d", lotteryId, halfDuration, purchaseStageEnd);

        if (block.timestamp <= purchaseStageEnd) {
            console.log("[contract] [getCurrentStage] returned PurchaseStage"); 
            return LotteryStage.PurchaseStage;
        } else if (block.timestamp <= lottery.endTime) {
            console.log("[contract] [getCurrentStage] returned RevealStage"); 
            return LotteryStage.RevealStage;
        }
        console.log("[contract] [getCurrentStage] returned Finalized"); 
        return LotteryStage.Finalized;
    }

    // Function to create a new lottery
    function createLottery(
        uint unixend,
        uint nooftickets,
        uint noofwinners, 
        uint minpercentage,
        uint ticketprice,
        bytes32 htmlhash, 
        string memory url
    ) public onlyOwner returns(uint) {
        console.log("[contract] [createLottery] block.timestamp: %d unixend: %d", block.timestamp, unixend);
        require(unixend > block.timestamp, "End time must be in the future");
        require(noofwinners > 0 && noofwinners <= nooftickets, "Invalid winners count");
        require(minpercentage > 0 && minpercentage <= 100, "Invalid minimum ticket percentage");

        currentLotteryNo++;
        console.log("[contract] [createLottery] currentLotteryNo: %d", currentLotteryNo);
        lotteries[currentLotteryNo] = Lottery({
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

        emit LotteryCreated(currentLotteryNo);

        return currentLotteryNo;
    }

    // Function to buy tickets
    function buyTicketTx(
        uint lottery_no, 
        uint quantity, 
        bytes32 hash_rnd_number
    ) public returns(uint sticketno) {
        Lottery storage lottery = lotteries[lottery_no];
        require(quantity > 0 && quantity <= 30, "Invalid ticket count");
        require(lottery.purchasedTickets + quantity <= lottery.totalTickets, "Exceeds total tickets");
        require(block.timestamp <= lottery.endTime, "Lottery ended");
        require(getCurrentStage(lottery_no) == LotteryStage.PurchaseStage, "Invalid lottery stage");

        console.log("[contract] [buyTicketTx] call block.timestamp: %d endTime: %d", block.timestamp, lottery.endTime);
        // Transfer payment tokens
        uint totalCost = quantity * lottery.ticketPrice;
        require(
            paymentToken.transferFrom(msg.sender, address(this), totalCost), 
            "Payment failed"
        );

        // Update user ticket information
        TicketInfo storage ticketInfo = userTickets[lottery_no][msg.sender];
        ticketInfo.ticketCount += quantity;
        ticketInfo.committedRandomNumber = hash_rnd_number;

        // Update lottery purchased tickets
        lottery.purchasedTickets += quantity;

        // Track purchase transaction
        purchaseTxs[lottery_no][purchaseTxCount] = msg.sender;
        purchaseTxCount++;

        return purchaseTxCount - 1;
    }

    // Function to reveal random number
    function revealRndNumberTx(
        uint lottery_no, 
        uint sticketno, 
        uint quantity, 
        uint rnd_number
    ) public {
        require(getCurrentStage(lottery_no) == LotteryStage.RevealStage, "Invalid lottery stage");
        TicketInfo storage ticketInfo = userTickets[lottery_no][msg.sender];
        require(!ticketInfo.revealed, "Already revealed");
        require(
            keccak256(abi.encodePacked(rnd_number)) == ticketInfo.committedRandomNumber, 
            "Invalid reveal"
        );

        ticketInfo.revealed = true;
    }

    // Get number of purchase transactions
    function getNumPurchaseTxs(uint lottery_no) public view returns(uint numpurchasetxs) {
        return purchaseTxCount;
    }

    // Get i-th purchased ticket transaction
    function getIthPurchasedTicketTx(
        uint i, 
        uint lottery_no
    ) public view returns(uint sticketno, uint quantity) {
        require(i < purchaseTxCount, "Invalid transaction index");
        address buyer = purchaseTxs[lottery_no][i];
        TicketInfo memory ticketInfo = userTickets[lottery_no][buyer];
        return (i, ticketInfo.ticketCount);
    }

    // Check if a specific ticket won
    function checkIfMyTicketWon(
        uint lottery_no, 
        uint ticket_no
    ) public view returns (bool won) {
        return checkIfAddrTicketWon(msg.sender, lottery_no, ticket_no);
    }

    // Check if a specific address's ticket won
    function checkIfAddrTicketWon(
        address addr, 
        uint lottery_no, 
        uint ticket_no
    ) public view returns (bool won) {
        address[] memory winners = lotteryWinners[lottery_no];
        for (uint i = 0; i < winners.length; i++) {
            if (winners[i] == addr) return true;
        }
        return false;
    }

    // Get i-th winning ticket
    function getIthWinningTicket(
        uint lottery_no, 
        uint i
    ) public view returns (uint ticketno) {
        require(i < lotteryWinners[lottery_no].length, "Invalid winner index");
        return i;
    }

    // Withdraw ticket refund
    function withdrawTicketRefund(uint lottery_no, uint sticket_no) public {
        Lottery storage lottery = lotteries[lottery_no];
        TicketInfo storage ticketInfo = userTickets[lottery_no][msg.sender];

        require(lottery.isCanceled, "Lottery not canceled");
        require(ticketInfo.ticketCount > 0, "No tickets to refund");

        uint refundAmount = ticketInfo.ticketCount * lottery.ticketPrice;
        require(
            paymentToken.transfer(msg.sender, refundAmount), 
            "Refund failed"
        );

        // Reset ticket count
        ticketInfo.ticketCount = 0;
    }

    // Get current lottery number
    function getCurrentLotteryNo() public view returns (uint lottery_no) {
        return currentLotteryNo;
    }

    // Withdraw ticket proceeds
    function withdrawTicketProceeds(uint lottery_no) public onlyOwner {
        Lottery storage lottery = lotteries[lottery_no];
        require(lottery.isFinalized && !lottery.isCanceled, "Lottery not eligible");

        uint totalProceeds = lottery.purchasedTickets * lottery.ticketPrice;
        require(
            paymentToken.transfer(owner, totalProceeds), 
            "Proceeds transfer failed"
        );
    }

    // Set payment token
    function setPaymentToken(address erctokenaddr) public onlyOwner {
        paymentToken = IERC20(erctokenaddr);
    }

    // Get payment token
    function getPaymentToken(uint lottery_no) public view returns (address erctokenaddr) {
        return address(paymentToken);
    }

    // Get lottery information
    function getLotteryInfo(uint lottery_no) public view returns (
        uint unixend, 
        uint nooftickets, 
        uint noofwinners, 
        uint minpercentage, 
        uint ticketprice
    ) {
        Lottery memory lottery = lotteries[lottery_no];
        return (
            lottery.endTime,
            lottery.totalTickets,
            lottery.winnersCount,
            lottery.minTicketPercentage,
            lottery.ticketPrice
        );
    }

    // Get lottery URL and description hash
    function getLotteryURL(uint lottery_no) public view returns(
        bytes32 htmlhash, 
        string memory url
    ) {
        Lottery memory lottery = lotteries[lottery_no];
        return (lottery.lotteryDescHash, lottery.lotteryDescUrl);
    }

    // Get lottery sales
    function getLotterySales(uint lottery_no) public view returns(uint numsold) {
        return lotteries[lottery_no].purchasedTickets;
    }
}