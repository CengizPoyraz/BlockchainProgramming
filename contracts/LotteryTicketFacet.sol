// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./LotteryFacet.sol";

contract LotteryTicketFacet {
    function buyTicketTx(uint256 lottery_no, uint256 quantity, bytes32 hash_rnd_number) 
        external 
        returns (uint256) 
    {
        LotteryFacet.DiamondStorage storage ds = getLotteryStorage();
        LotteryFacet.LotteryState storage lottery = ds.lotteries[lottery_no];
        
        require(block.timestamp < lottery.endTime, "Lottery ended");
        require(quantity > 0 && quantity <= 30, "Invalid quantity");
        require(lottery.soldTickets + quantity <= lottery.totalTickets, "Not enough tickets");

        // Purchase logic...
        
        return lottery.soldTickets + 1;
    }

    function getLotteryStorage() internal pure returns (LotteryFacet.DiamondStorage storage ds) {
        bytes32 position = keccak256("diamond.lottery.storage");
        assembly {
            ds.slot := position
        }
    }
}