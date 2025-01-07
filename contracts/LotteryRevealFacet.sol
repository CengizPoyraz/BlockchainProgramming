// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./LibLotteryStorage.sol";

contract LotteryRevealFacet {
    using LibLotteryStorage for LibLotteryStorage.LotteryState;

    function revealRndNumberTx(
        uint lottery_no, 
        uint sticketno, 
        uint quantity, 
        uint rnd_number
    ) external {
        LibLotteryStorage.LotteryState storage ds = LibLotteryStorage.diamondStorage();
        LibLotteryStorage.TicketInfo storage ticketInfo = ds.userTickets[lottery_no][msg.sender];
        
        require(
            getCurrentStage(lottery_no) == LotteryCoreFacet.LotteryStage.RevealStage, 
            "Invalid stage"
        );
        require(!ticketInfo.revealed, "Already revealed");
        require(
            keccak256(abi.encodePacked(rnd_number)) == ticketInfo.committedRandomNumber,
            "Invalid reveal"
        );

        ticketInfo.revealed = true;
        emit RandomNumberRevealed(lottery_no, msg.sender);
    }

    function getCurrentStage(uint lottery_no) internal view returns (LotteryCoreFacet.LotteryStage) {
        return LotteryCoreFacet(address(this)).getCurrentStage(lottery_no);
    }
}