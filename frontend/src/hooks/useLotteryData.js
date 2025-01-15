// src/hooks/useLotteryData.js
import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { useLottery } from '../context/LotteryContext';

export const useLotteryData = (lotteryId) => {
  const { contract } = useLottery();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        if (!contract || !lotteryId) return;
        setLoading(true);

        const [info, urlInfo, sales] = await Promise.all([
          contract.getLotteryInfo(lotteryId),
          contract.getLotteryURL(lotteryId),
          contract.getLotterySales(lotteryId)
        ]);

        setData({
          endTime: info.endTime.toNumber(),
          noOfTickets: info.noOfTickets.toNumber(),
          noOfWinners: info.noOfWinners.toNumber(),
          minPercentage: info.minPercentage.toNumber(),
          ticketPrice: ethers.utils.formatEther(info.ticketPrice),
          htmlHash: urlInfo.htmlHash,
          url: urlInfo.url,
          ticketsSold: sales.toNumber()
        });
        setError(null);
      } catch (err) {
        setError('Failed to fetch lottery data: ' + err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [contract, lotteryId]);

  return { data, loading, error };
};