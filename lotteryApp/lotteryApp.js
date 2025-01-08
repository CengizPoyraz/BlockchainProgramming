import React, { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Alert, AlertDescription } from '@/components/ui/alert';

const LotteryApp = () => {
  const [account, setAccount] = useState('');
  const [provider, setProvider] = useState(null);
  const [contract, setContract] = useState(null);
  const [currentLottery, setCurrentLottery] = useState(null);
  const [ticketQuantity, setTicketQuantity] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const init = async () => {
      if (typeof window.ethereum !== 'undefined') {
        try {
          const provider = new ethers.providers.Web3Provider(window.ethereum);
          const accounts = await provider.send('eth_requestAccounts', []);
          setAccount(accounts[0]);
          setProvider(provider);
          
          // Initialize contract (address will need to be updated after deployment)
          const contractAddress = "YOUR_CONTRACT_ADDRESS";
          const contractABI = ["YOUR_CONTRACT_ABI"];
          const contract = new ethers.Contract(contractAddress, contractABI, provider.getSigner());
          setContract(contract);
          
          // Get current lottery
          const lotteryNo = await contract.getCurrentLotteryNo();
          const lotteryInfo = await contract.getLotteryInfo(lotteryNo);
          setCurrentLottery({
            no: lotteryNo,
            endTime: lotteryInfo[0],
            totalTickets: lotteryInfo[1],
            winners: lotteryInfo[2],
            minPercentage: lotteryInfo[3],
            ticketPrice: lotteryInfo[4]
          });
        } catch (err) {
          setError('Failed to connect to wallet');
          console.error(err);
        }
      } else {
        setError('Please install MetaMask');
      }
    };

    init();
  }, []);

  const buyTickets = async () => {
    try {
      setLoading(true);
      setError('');
      
      // Generate random number for commitment
      const randomNumber = ethers.BigNumber.from(ethers.utils.randomBytes(32));
      const commitment = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(['uint256'], [randomNumber]));
      
      // Buy tickets
      const tx = await contract.buyTicketTx(
        currentLottery.no,
        ticketQuantity,
        commitment,
        {
          value: currentLottery.ticketPrice.mul(ticketQuantity)
        }
      );
      
      await tx.wait();
      
      // Store random number for later reveal
      localStorage.setItem(`lottery_${currentLottery.no}_random`, randomNumber.toString());
      
    } catch (err) {
      setError('Failed to buy tickets');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const revealNumber = async () => {
    try {
      setLoading(true);
      setError('');
      
      const randomNumber = localStorage.getItem(`lottery_${currentLottery.no}_random`);
      if (!randomNumber) {
        throw new Error('No random number found for this lottery');
      }
      
      const tx = await contract.revealRndNumberTx(
        currentLottery.no,
        0, // ticket number
        ticketQuantity,
        randomNumber
      );
      
      await tx.wait();
      
    } catch (err) {
      setError('Failed to reveal number');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container mx-auto p-4">
      <Card>
        <CardHeader>
          <CardTitle>Lottery Dashboard</CardTitle>
          <CardDescription>Connected Account: {account || 'Not Connected'}</CardDescription>
        </CardHeader>
        <CardContent>
          {currentLottery && (
            <div className="space-y-4">
              <div>
                <h3 className="text-lg font-medium">Current Lottery #{currentLottery.no}</h3>
                <p>End Time: {new Date(currentLottery.endTime * 1000).toLocaleString()}</p>
                <p>Ticket Price: {ethers.utils.formatEther(currentLottery.ticketPrice)} ETH</p>
                <p>Total Tickets: {currentLottery.totalTickets.toString()}</p>
                <p>Winners: {currentLottery.winners.toString()}</p>
              </div>
              
              <div className="space-y-2">
                <Input 
                  type="number" 
                  min="1" 
                  max="30"
                  value={ticketQuantity}
                  onChange={(e) => setTicketQuantity(Number(e.target.value))}
                  placeholder="Number of tickets"
                />
                <Button 
                  onClick={buyTickets} 
                  disabled={loading}
                  className="w-full"
                >
                  Buy Tickets
                </Button>
                <Button 
                  onClick={revealNumber} 
                  disabled={loading}
                  className="w-full"
                >
                  Reveal Number
                </Button>
              </div>
            </div>
          )}
          
          {error && (
            <Alert variant="destructive" className="mt-4">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          )}
        </CardContent>
      </Card>
    </div>
  );
};

export default LotteryApp;