// src/context/LotteryContext.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useWeb3 } from './Web3Context';
import { LOTTERY_ABI, LOTTERY_ADDRESS } from '../contracts/addresses';

const LotteryContext = createContext();

export const LotteryProvider = ({ children }) => {
  const { signer, provider } = useWeb3();
  const [contract, setContract] = useState(null);
  const [currentLottery, setCurrentLottery] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (provider) {
      const lotteryContract = new ethers.Contract(
        LOTTERY_ADDRESS,
        LOTTERY_ABI,
        provider
      );
      setContract(lotteryContract);
      loadCurrentLottery();
    }
  }, [provider]);

  const loadCurrentLottery = async () => {
    try {
      if (!contract) return;
      setLoading(true);
      const lotteryNo = await contract.getCurrentLotteryNo();
      const info = await contract.getLotteryInfo(lotteryNo);
      const sales = await contract.getLotterySales(lotteryNo);

      setCurrentLottery({
        number: lotteryNo,
        endTime: info.endTime.toNumber(),
        noOfTickets: info.noOfTickets.toNumber(),
        noOfWinners: info.noOfWinners.toNumber(),
        minPercentage: info.minPercentage.toNumber(),
        ticketPrice: ethers.utils.formatEther(info.ticketPrice),
        ticketsSold: sales.toNumber()
      });
    } catch (err) {
      setError('Failed to load lottery info: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const buyTickets = async (quantity, randomNumberHash) => {
    try {
      if (!contract || !signer) throw new Error('Not connected');
      const contractWithSigner = contract.connect(signer);
      const tx = await contractWithSigner.buyTicketTx(quantity, randomNumberHash);
      await tx.wait();
      await loadCurrentLottery();
      return tx;
    } catch (err) {
      throw new Error('Failed to buy tickets: ' + err.message);
    }
  };

  const revealNumbers = async (startTicketNo, quantity, randomNumber) => {
    try {
      if (!contract || !signer) throw new Error('Not connected');
      const contractWithSigner = contract.connect(signer);
      const tx = await contractWithSigner.revealRndNumberTx(
        startTicketNo,
        quantity,
        randomNumber
      );
      await tx.wait();
      return tx;
    } catch (err) {
      throw new Error('Failed to reveal numbers: ' + err.message);
    }
  };

  return (
    <LotteryContext.Provider
      value={{
        contract,
        currentLottery,
        loading,
        error,
        buyTickets,
        revealNumbers,
        refreshLottery: loadCurrentLottery
      }}
    >
      {children}
    </LotteryContext.Provider>
  );
};

export const useLottery = () => useContext(LotteryContext);