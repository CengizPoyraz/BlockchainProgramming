// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library LibLottery {
    bytes32 constant LOTTERY_STORAGE_POSITION = keccak256("lottery.standard.storage");

    // Events
    event WinningNumbersGenerated(uint indexed lotteryId, uint256[] winningNumbers);
    event WinnerSelected(uint indexed lotteryId, address indexed winner, uint256 prizeAmount);
    event PrizeClaimed(uint indexed lotteryId, address indexed winner, uint256 amount);

    // Structs
    struct Lottery {
        uint256 beginTime;             // Start time of lottery
        uint256 endTime;              // End time of lottery
        uint256 totalTickets;          // Total available tickets
        uint256 purchasedTickets;      // Number of tickets sold
        uint256 winnersCount;          // Number of winners
        uint256 minTicketPercentage;   // Minimum percentage of tickets that must be sold
        uint256 ticketPrice;           // Price per ticket
        uint256 prizePool;             // Total prize pool
        bytes32 lotteryDescHash;       // Hash of lottery description
        string lotteryDescUrl;         // URL to lottery description
        bool isCanceled;              // Whether lottery is canceled
        bool isFinalized;             // Whether lottery is finalized
        uint256[] winningNumbers;      // Winning ticket numbers
        mapping(uint256 => bool) usedTicketNumbers; // Track used ticket numbers
    }

    struct TicketInfo {
        uint256 ticketCount;           // Number of tickets purchased
        bytes32 committedRandomNumber; // Committed random number hash
        bool revealed;                // Whether random number was revealed
        uint256 randomNumber;         // Revealed random number
        uint256[] ticketNumbers;      // Assigned ticket numbers
        bool hasClaimed;              // Whether prizes have been claimed
    }

    struct LotteryStorage {
        mapping(uint256 => Lottery) lotteries;
        mapping(uint256 => mapping(address => TicketInfo)) userTickets;
        mapping(uint256 => address[]) lotteryWinners;
        uint256 currentLotteryNo;
        IERC20 paymentToken;
        mapping(uint256 => mapping(uint256 => address)) purchaseTxs;
        uint256 purchaseTxCount;
    }

    // Main storage function
    function lotteryStorage() internal pure returns (LotteryStorage storage ls) {
        bytes32 position = LOTTERY_STORAGE_POSITION;
        assembly {
            ls.slot := position
        }
    }

    // Core lottery functions
    function createLottery(
        uint256 unixend,
        uint256 nooftickets,
        uint256 noofwinners,
        uint256 minpercentage,
        uint256 ticketprice,
        bytes32 htmlhash,
        string memory url
    ) internal returns (uint256) {
        require(unixend > block.timestamp, "End time must be future");
        require(noofwinners > 0 && noofwinners <= nooftickets, "Invalid winners count");
        require(minpercentage > 0 && minpercentage <= 100, "Invalid percentage");
        
        LotteryStorage storage ls = lotteryStorage();
        ls.currentLotteryNo++;
        uint256 lotteryId = ls.currentLotteryNo;
        
        Lottery storage lottery = ls.lotteries[lotteryId];
        lottery.beginTime = block.timestamp;
        lottery.endTime = unixend;
        lottery.totalTickets = nooftickets;
        lottery.purchasedTickets = 0;
        lottery.winnersCount = noofwinners;
        lottery.minTicketPercentage = minpercentage;
        lottery.ticketPrice = ticketprice;
        lottery.lotteryDescHash = htmlhash;
        lottery.lotteryDescUrl = url;
        lottery.isCanceled = false;
        lottery.isFinalized = false;
        lottery.prizePool = 0;

        return lotteryId;
    }

    function buyTicketTx(
        uint256 lotteryId,
        uint256 quantity,
        bytes32 hash_rnd_number
    ) internal returns (uint256[] memory) {
        LotteryStorage storage ls = lotteryStorage();
        Lottery storage lottery = ls.lotteries[lotteryId];
        
        require(!lottery.isCanceled, "Lottery is canceled");
        require(block.timestamp <= lottery.endTime, "Lottery ended");
        require(lottery.purchasedTickets + quantity <= lottery.totalTickets, "Not enough tickets");

        // Handle payment
        uint256 totalCost = quantity * lottery.ticketPrice;
        require(
            ls.paymentToken.transferFrom(msg.sender, address(this), totalCost),
            "Payment failed"
        );

        // Update prize pool
        lottery.prizePool += totalCost;

        // Store purchase transaction
        ls.purchaseTxs[lotteryId][ls.purchaseTxCount] = msg.sender;
        uint256 txId = ls.purchaseTxCount;
        ls.purchaseTxCount++;

        // Generate and store ticket numbers
        TicketInfo storage ticketInfo = ls.userTickets[lotteryId][msg.sender];
        uint256[] memory ticketNumbers = new uint256[](quantity);
        
        for (uint256 i = 0; i < quantity; i++) {
            uint256 ticketNumber = uint256(keccak256(abi.encodePacked(
                block.timestamp,
                msg.sender,
                lottery.purchasedTickets + i,
                hash_rnd_number
            ))) % lottery.totalTickets;
            
            // Ensure unique ticket numbers
            while (lottery.usedTicketNumbers[ticketNumber]) {
                ticketNumber = (ticketNumber + 1) % lottery.totalTickets;
            }
            
            lottery.usedTicketNumbers[ticketNumber] = true;
            ticketNumbers[i] = ticketNumber;
            ticketInfo.ticketNumbers.push(ticketNumber);
        }

        // Update ticket information
        ticketInfo.ticketCount += quantity;
        ticketInfo.committedRandomNumber = hash_rnd_number;
        ticketInfo.revealed = false;
        lottery.purchasedTickets += quantity;

        return ticketNumbers;
    }

    function revealRndNumberTx(
        uint256 lotteryId,
        uint256 rnd_number
    ) internal {
        LotteryStorage storage ls = lotteryStorage();
        TicketInfo storage ticketInfo = ls.userTickets[lotteryId][msg.sender];

        require(!ticketInfo.revealed, "Already revealed");
        require(
            keccak256(abi.encodePacked(rnd_number)) == ticketInfo.committedRandomNumber,
            "Invalid random number"
        );

        ticketInfo.randomNumber = rnd_number;
        ticketInfo.revealed = true;
    }

    function determineLotteryWinners(uint256 lotteryId) internal {
        LotteryStorage storage ls = lotteryStorage();
        Lottery storage lottery = ls.lotteries[lotteryId];

        require(!lottery.isFinalized && !lottery.isCanceled, "Invalid state");
        require(block.timestamp > lottery.endTime, "Lottery not ended");

        // Check minimum participation
        uint256 minRequired = (lottery.totalTickets * lottery.minTicketPercentage) / 100;
        require(lottery.purchasedTickets >= minRequired, "Minimum tickets not met");

        // Generate winning numbers using aggregated entropy
        uint256 entropy = 0;
        for (uint256 i = 0; i < ls.purchaseTxCount; i++) {
            address participant = ls.purchaseTxs[lotteryId][i];
            TicketInfo storage ticketInfo = ls.userTickets[lotteryId][participant];
            if (ticketInfo.revealed) {
                entropy ^= ticketInfo.randomNumber;
            }
        }

        lottery.winningNumbers = new uint256[](lottery.winnersCount);
        for (uint256 i = 0; i < lottery.winnersCount; i++) {
            lottery.winningNumbers[i] = uint256(keccak256(abi.encodePacked(
                entropy,
                block.timestamp,
                i
            ))) % lottery.totalTickets;
        }

        emit WinningNumbersGenerated(lotteryId, lottery.winningNumbers);

        // Mark lottery as finalized
        lottery.isFinalized = true;
    }

    function claimPrize(uint256 lotteryId) internal returns (uint256) {
        LotteryStorage storage ls = lotteryStorage();
        Lottery storage lottery = ls.lotteries[lotteryId];
        TicketInfo storage ticketInfo = ls.userTickets[lotteryId][msg.sender];

        require(lottery.isFinalized, "Lottery not finalized");
        require(!ticketInfo.hasClaimed, "Already claimed");
        require(ticketInfo.ticketCount > 0, "No tickets owned");

        uint256 winningTicketCount = 0;
        for (uint256 i = 0; i < ticketInfo.ticketNumbers.length; i++) {
            for (uint256 j = 0; j < lottery.winningNumbers.length; j++) {
                if (ticketInfo.ticketNumbers[i] == lottery.winningNumbers[j]) {
                    winningTicketCount++;
                }
            }
        }

        require(winningTicketCount > 0, "No winning tickets");

        // Calculate prize amount
        uint256 prizePerWinner = lottery.prizePool / lottery.winnersCount;
        uint256 totalPrize = prizePerWinner * winningTicketCount;

        // Mark as claimed and transfer prize
        ticketInfo.hasClaimed = true;
        require(
            ls.paymentToken.transfer(msg.sender, totalPrize),
            "Prize transfer failed"
        );

        emit PrizeClaimed(lotteryId, msg.sender, totalPrize);
        return totalPrize;
    }

    // View functions
    function getLotteryInfo(uint256 lotteryId) internal view returns (
        uint256 endTime,
        uint256 totalTickets,
        uint256 purchasedTickets,
        uint256 winnersCount,
        uint256 minPercentage,
        uint256 ticketPrice,
        uint256 prizePool,
        bool isCanceled,
        bool isFinalized
    ) {
        LotteryStorage storage ls = lotteryStorage();
        Lottery storage lottery = ls.lotteries[lotteryId];

        return (
            lottery.endTime,
            lottery.totalTickets,
            lottery.purchasedTickets,
            lottery.winnersCount,
            lottery.minTicketPercentage,
            lottery.ticketPrice,
            lottery.prizePool,
            lottery.isCanceled,
            lottery.isFinalized
        );
    }

    function getUserTickets(
        uint256 lotteryId,
        address user
    ) internal view returns (
        uint256 ticketCount,
        bool revealed,
        uint256[] memory ticketNumbers,
        bool hasClaimed
    ) {
        LotteryStorage storage ls = lotteryStorage();
        TicketInfo storage ticketInfo = ls.userTickets[lotteryId][user];

        return (
            ticketInfo.ticketCount,
            ticketInfo.revealed,
            ticketInfo.ticketNumbers,
            ticketInfo.hasClaimed
        );
    }

    function getWinningNumbers(
        uint256 lotteryId
    ) internal view returns (uint256[] memory) {
        LotteryStorage storage ls = lotteryStorage();
        return ls.lotteries[lotteryId].winningNumbers;
    }

    function isWinningTicket(
        uint256 lotteryId,
        uint256 ticketNumber
    ) internal view returns (bool) {
        LotteryStorage storage ls = lotteryStorage();
        Lottery storage lottery = ls.lotteries[lotteryId];

        for (uint256 i = 0; i < lottery.winningNumbers.length; i++) {
            if (lottery.winningNumbers[i] == ticketNumber) {
                return true;
            }
        }
        return false;
    }
}
