// LotteryFacet.sol
import { LibDiamond } from "./diamond/Diamond.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LotteryFacet {
    struct LotteryState {
        uint256 endTime;
        uint256 totalTickets;
        uint256 soldTickets;
        uint256 winnerCount;
        uint256 minimumTicketPercentage;
        uint256 ticketPrice;
        bytes32 htmlHash;
        string url;
        IERC20 paymentToken;
        bool isCanceled;
        mapping(address => uint256) ticketsPurchased;
        mapping(address => bytes32) randomCommitments;
        mapping(address => bool) randomRevealed;
        mapping(uint256 => address) ticketOwners;
        uint256[] winningTickets;
    }

    struct DiamondStorage {
        mapping(uint256 => LotteryState) lotteries;
        uint256 currentLotteryNo;
        address paymentToken;
    }

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = keccak256("diamond.lottery.storage");
        assembly {
            ds.slot := position
        }
    }

    // Main lottery functions
    function createLottery(
        uint256 endTime,
        uint256 nooftickets,
        uint256 noofwinners,
        uint256 minpercentage,
        uint256 ticketprice,
        bytes32 htmlhash,
        string memory url
    ) external returns (uint256) {
        LibDiamond.enforceIsContractOwner();
        DiamondStorage storage ds = diamondStorage();
        
        uint256 lotteryNo = ++ds.currentLotteryNo;
        LotteryState storage lottery = ds.lotteries[lotteryNo];
        
        lottery.endTime = endTime;
        lottery.totalTickets = nooftickets;
        lottery.winnerCount = noofwinners;
        lottery.minimumTicketPercentage = minpercentage;
        lottery.ticketPrice = ticketprice;
        lottery.htmlHash = htmlhash;
        lottery.url = url;

        return lotteryNo;
    }

    // Additional lottery functions...
}

// OwnershipFacet.sol
contract OwnershipFacet {
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
}