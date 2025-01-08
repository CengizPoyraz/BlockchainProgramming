// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { LibDiamond } from "../libraries/LibDiamond.sol";
import { IERC173 } from "../interfaces/IERC173.sol";

contract OwnershipFacet is IERC173 {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function transferOwnership(address _newOwner) external override {
        LibDiamond.enforceIsContractOwner();
        require(_newOwner != address(0), "Ownership: New owner cannot be zero address");
        LibDiamond.setContractOwner(_newOwner);
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /// @notice Query if an address is the current contract owner
    /// @param _address The address to query
    /// @return bool True if the address is the owner, false otherwise
    function isOwner(address _address) external view returns (bool) {
        return _address == LibDiamond.contractOwner();
    }

    /// @notice Renounce ownership of the contract
    /// @dev Leaves the contract without owner. It will not be possible to call
    /// functions with the `onlyOwner` modifier anymore.
    function renounceOwnership() external {
        LibDiamond.enforceIsContractOwner();
        emit OwnershipTransferred(msg.sender, address(0));
        LibDiamond.setContractOwner(address(0));
    }

    /// @notice Get the history of ownership transfers (requires storage)
    /// @return previousOwners Array of previous owner addresses
    /// @return timestamps Array of timestamps when ownership was transferred
    function getOwnershipHistory() external view returns (
        address[] memory previousOwners,
        uint256[] memory timestamps
    ) {
        // Note: This is a stub implementation.
        // In a real implementation, you would need to store ownership history
        // in the diamond storage.
        previousOwners = new address[](0);
        timestamps = new uint256[](0);
    }

    /// @notice Check if the contract has an owner
    /// @return bool True if the contract has an owner, false if ownership was renounced
    function hasOwner() external view returns (bool) {
        return LibDiamond.contractOwner() != address(0);
    }
}
