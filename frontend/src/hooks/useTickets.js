// src/hooks/useTickets.js
import { useState, useEffect } from 'react';
import { useLottery } from '../context/LotteryContext';
import { useWeb3 } from '../context/Web3Context';

export const useTickets = (lotteryId) => {
  const { contract } = useLottery();
  const { account } = useWeb3();
  const [tickets, setTickets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchTickets = async () => {
      if (!contract || !account || !lotteryId) return;
      
      try {
        setLoading(true);
        const numTx = await contract.getNumPurchaseTxs(lotteryId);
        const userTickets = [];

        for (let i = 0; i < numTx; i++) {
          const tx = await contract.getIthPurchasedTicketTx(i, lotteryId);
          const startTicket = tx.startTicketNo.toNumber();
          const quantity = tx.quantity.toNumber();

          // Check each ticket in the transaction
          for (let j = 0; j < quantity; j++) {
            const ticketNo = startTicket + j;
            const isWinner = await contract.checkIfAddrTicketWon(
              account,
              lotteryId,
              ticketNo
            );
            
            userTickets.push({
              ticketNo,
              isWinner,
              revealed: false // You might want to add a check for this
            });
          }
        }

        setTickets(userTickets);
        setError(null);
      } catch (err) {
        setError('Failed to fetch tickets: ' + err.message);
      } finally {
        setLoading(false);
      }
    };

    fetchTickets();
  }, [contract, account, lotteryId]);

  return { tickets, loading, error };
};