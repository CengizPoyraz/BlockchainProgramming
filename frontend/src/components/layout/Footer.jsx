// src/components/layout/Footer.jsx
import React from 'react';

const Footer = () => {
  return (
    <footer className="bg-white border-t">
      <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center">
          <div className="text-gray-500 text-sm">
            © 2024 Lottery dApp. All rights reserved.
          </div>
          <div className="flex space-x-6">
            <a
              href="https://github.com/yourusername/lottery-dapp"
              target="_blank"
              rel="noopener noreferrer"
              className="text-gray-500 hover:text-gray-900"
            >
              GitHub
            </a>
            <a
              href="#"
              className="text-gray-500 hover:text-gray-900"
            >
              Terms
            </a>
            <a
              href="#"
              className="text-gray-500 hover:text-gray-900"
            >
              Privacy
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;