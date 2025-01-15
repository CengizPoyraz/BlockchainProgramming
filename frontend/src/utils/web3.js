// src/utils/web3.js
import { ethers } from 'ethers';

export const shortenAddress = (address) => {
  if (!address) return '';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

export const formatEther = (wei) => {
  if (!wei) return '0';
  return ethers.utils.formatEther(wei);
};

export const parseEther = (eth) => {
  if (!eth) return ethers.constants.Zero;
  return ethers.utils.parseEther(eth.toString());
};

export const generateRandomNumber = () => {
  const randomBytes = ethers.utils.randomBytes(32);
  const number = ethers.BigNumber.from(randomBytes);
  const hash = ethers.utils.keccak256(randomBytes);
  return { number, hash };
};

// src/utils/time.js
export const formatTimeRemaining = (endTime) => {
  const now = Math.floor(Date.now() / 1000);
  const remaining = endTime - now;

  if (remaining <= 0) return 'Ended';

  const days = Math.floor(remaining / 86400);
  const hours = Math.floor((remaining % 86400) / 3600);
  const minutes = Math.floor((remaining % 3600) / 60);
  const seconds = remaining % 60;

  if (days > 0) return `${days}d ${hours}h ${minutes}m`;
  if (hours > 0) return `${hours}h ${minutes}m ${seconds}s`;
  if (minutes > 0) return `${minutes}m ${seconds}s`;
  return `${seconds}s`;
};

export const getLotteryPhase = (endTime) => {
  const now = Math.floor(Date.now() / 1000);
  const halfway = endTime - ((endTime - now) / 2);

  if (now >= endTime) return 'ended';
  if (now >= halfway) return 'reveal';
  return 'purchase';
};

// src/utils/validation.js
export const validateLotteryParams = (params) => {
  const errors = {};

  if (!params.endDate || !params.endTime) {
    errors.time = 'End time is required';
  } else {
    const endDateTime = new Date(`${params.endDate}T${params.endTime}`);
    if (endDateTime <= new Date()) {
      errors.time = 'End time must be in the future';
    }
  }

  if (!params.noOfTickets || params.noOfTickets < 1) {
    errors.noOfTickets = 'Must have at least 1 ticket';
  }

  if (!params.noOfWinners || params.noOfWinners < 1) {
    errors.noOfWinners = 'Must have at least 1 winner';
  }

  if (params.noOfWinners > params.noOfTickets) {
    errors.noOfWinners = 'Winners cannot exceed number of tickets';
  }

  if (!params.minPercentage || params.minPercentage < 1 || params.minPercentage > 100) {
    errors.minPercentage = 'Percentage must be between 1 and 100';
  }

  if (!params.ticketPrice || params.ticketPrice <= 0) {
    errors.ticketPrice = 'Ticket price must be greater than 0';
  }

  return {
    isValid: Object.keys(errors).length === 0,
    errors
  };
};