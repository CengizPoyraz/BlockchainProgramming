// src/hooks/useContract.js
import { useEffect, useState } from 'react';
import { ethers } from 'ethers';
import { useWeb3 } from '../context/Web3Context';

export const useContract = (address, abi) => {
  const { provider, signer } = useWeb3();
  const [contract, setContract] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (provider && address && abi) {
      try {
        const contract = new ethers.Contract(
          address,
          abi,
          signer || provider
        );
        setContract(contract);
        setError(null);
      } catch (err) {
        setError('Failed to load contract');
        console.error(err);
      }
    }
  }, [provider, signer, address, abi]);

  return { contract, error };
};