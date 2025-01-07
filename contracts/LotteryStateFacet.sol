// LotteryStateFacet.sol
import "LotteryFacet.sol"

contract LotteryStateFacet {
    function getLotteryInfo(uint256 lottery_no) external view returns (
        uint256 unixbeg,
        uint256 nooftickets,
        uint256 noofwinners,
        uint256 minpercentage,
        uint256 ticketprice
    ) {
        LotteryFacet.DiamondStorage storage ds = getLotteryStorage();
        LotteryFacet.LotteryState storage lottery = ds.lotteries[lottery_no];
        
        return (
            lottery.endTime,
            lottery.totalTickets,
            lottery.winnerCount,
            lottery.minimumTicketPercentage,
            lottery.ticketPrice
        );
    }

    function getLotteryStorage() internal pure returns (LotteryFacet.DiamondStorage storage ds) {
        bytes32 position = keccak256("diamond.lottery.storage");
        assembly {
            ds.slot := position
        }
    }
}