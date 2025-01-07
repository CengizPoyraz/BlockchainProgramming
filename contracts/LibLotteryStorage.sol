// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Diamond storage library
library LibLotteryStorage {
    bytes32 constant LOTTERY_STORAGE_POSITION = keccak256("company.lottery.storage");

    struct LotteryState {
        // Owner of the contract
        address owner;
        // Current lottery number
        uint currentLotteryNo;
        // Payment token 
        IERC20 paymentToken;
        // Mapping to store lotteries
        mapping(uint => Lottery) lotteries;
        // Mapping to track user tickets per lottery
        mapping(uint => mapping(address => TicketInfo)) userTickets;
        // Mapping to store winners of each lottery
        mapping(uint => address[]) lotteryWinners;
        // Mapping to track purchase transactions
        mapping(uint => mapping(uint => address)) purchaseTxs;
        uint purchaseTxCount;
    }

    struct Lottery {
        uint beginTime;             
        uint endTime;              
        uint totalTickets;          
        uint purchasedTickets;      
        uint winnersCount;          
        uint minTicketPercentage;   
        uint ticketPrice;           
        bytes32 lotteryDescHash;    
        string lotteryDescUrl;      
        bool isCanceled;            
        bool isFinalized;           
    }

    struct TicketInfo {
        uint ticketCount;           
        bytes32 committedRandomNumber; 
        bool revealed;                 
    }

    function diamondStorage() internal pure returns (LotteryState storage ds) {
        bytes32 position = LOTTERY_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}