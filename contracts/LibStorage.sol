// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;


library LibStorage {
    // Storage for the lottery system
    struct LotteryStorage {
        // Lottery state
        uint256 currentLotteryNo;
        mapping(uint256 => LotteryInfo) lotteries;
        mapping(uint256 => PurchaseTransaction[]) purchaseTxs;
        mapping(uint256 => address) paymentTokens;
    }

    struct LotteryInfo {
        uint256 endTime;
        uint256 noOfTickets;
        uint256 noOfWinners;
        uint256 minPercentage;
        uint256 ticketPrice;
        bytes32 htmlHash;
        string url;
        uint256 ticketsSold;
        bool finished;
        mapping(uint256 => Ticket) tickets;
        mapping(uint256 => uint256) winningTickets;
    }

    struct Ticket {
        address owner;
        bytes32 hashRndNumber;
        bool revealed;
        uint256 rndNumber;
    }

    struct PurchaseTransaction {
        uint256 startTicketNo;
        uint256 quantity;
    }

    // Diamond storage position
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("lottery.storage");

    function diamondStorage() internal pure returns (LotteryStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // Function to initialize storage - called during deployment
    function initStorage() internal {
        LotteryStorage storage ds = diamondStorage();
        if (ds.currentLotteryNo == 0) {
            ds.currentLotteryNo = 0; // Start with 0, first lottery will be #1
        }
    }

    // Facet structs for managing diamond cuts
    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // facet addresses
        address[] facetAddresses;
        // owner of the contract
        address contractOwner;
    }

    bytes32 constant DIAMOND_STORAGE_POSITION_CORE = keccak256("diamond.standard.diamond.storage");

    function diamondStorageCore() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION_CORE;
        assembly {
            ds.slot := position
        }
    }

    // Access control modifiers
    function enforceIsContractOwner() internal view {
        require(
            msg.sender == diamondStorageCore().contractOwner,
            "LibStorage: Must be contract owner"
        );
    }

    // Owner management
    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorageCore();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address owner_) {
        owner_ = diamondStorageCore().contractOwner;
    }

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
}