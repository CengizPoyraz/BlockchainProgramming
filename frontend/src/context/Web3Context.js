// src/context/Web3Context.jsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { Alert } from '../components/ui/Alert';

const Web3Context = createContext();

export const Web3Provider = ({ children }) => {
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [networkId, setNetworkId] = useState(null);
  const [connecting, setConnecting] = useState(true);
  const [error, setError] = useState(null);

  const connectWallet = async () => {
    try {
      const { ethereum } = window;
      if (!ethereum) {
        setError('Please install MetaMask!');
        return;
      }

      setConnecting(true);
      const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
      const provider = new ethers.providers.Web3Provider(ethereum);
      const signer = provider.getSigner();
      const network = await provider.getNetwork();

      setAccount(accounts[0]);
      setProvider(provider);
      setSigner(signer);
      setNetworkId(network.chainId);
      setError(null);
    } catch (error) {
      setError('Failed to connect wallet: ' + error.message);
    } finally {
      setConnecting(false);
    }
  };

  const disconnectWallet = () => {
    setAccount(null);
    setProvider(null);
    setSigner(null);
    setNetworkId(null);
  };

  useEffect(() => {
    const checkConnection = async () => {
      const { ethereum } = window;
      if (ethereum && ethereum.selectedAddress) {
        connectWallet();
      } else {
        setConnecting(false);
      }
    };

    checkConnection();

    // Listen for account changes
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length > 0) {
          setAccount(accounts[0]);
        } else {
          disconnectWallet();
        }
      });

      window.ethereum.on('chainChanged', (chainId) => {
        window.location.reload();
      });
    }

    return () => {
      if (window.ethereum) {
        window.ethereum.removeAllListeners();
      }
    };
  }, []);

  return (
    <Web3Context.Provider
      value={{
        account,
        provider,
        signer,
        networkId,
        connecting,
        error,
        connectWallet,
        disconnectWallet
      }}
    >
      {children}
      {error && <Alert variant="error" message={error} />}
    </Web3Context.Provider>
  );
};

export const useWeb3 = () => useContext(Web3Context);