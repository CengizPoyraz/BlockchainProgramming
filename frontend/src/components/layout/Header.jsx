// src/components/layout/Header.jsx
import React from 'react';
import { Link } from 'react-router-dom';
import { useWeb3 } from '../../context/Web3Context';
import { Button } from '../ui/Button';
import { shortenAddress } from '../../utils/web3';

const Header = () => {
  const { account, connectWallet, disconnectWallet } = useWeb3();

  return (
    <header className="bg-white shadow">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex">
            <div className="flex-shrink-0 flex items-center">
              <Link to="/" className="text-2xl font-bold text-blue-600">
                Lottery dApp
              </Link>
            </div>
            <nav className="ml-6 flex space-x-4">
              <Link
                to="/"
                className="px-3 py-2 rounded-md text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Home
              </Link>
              <Link
                to="/my-tickets"
                className="px-3 py-2 rounded-md text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                My Tickets
              </Link>
              <Link
                to="/admin"
                className="px-3 py-2 rounded-md text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Admin
              </Link>
            </nav>
          </div>
          <div className="flex items-center">
            {account ? (
              <div className="flex items-center space-x-4">
                <span className="text-sm text-gray-700">
                  {shortenAddress(account)}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={disconnectWallet}
                >
                  Disconnect
                </Button>
              </div>
            ) : (
              <Button
                variant="primary"
                size="sm"
                onClick={connectWallet}
              >
                Connect Wallet
              </Button>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;