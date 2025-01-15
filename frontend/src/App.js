import logo from './logo.svg';
import './App.css';

import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Web3Provider } from './context/Web3Context';
import { LotteryProvider } from './context/LotteryContext';
import Layout from './components/layout/Layout';
import Home from './pages/Home';
import Admin from './pages/Admin';
import LotteryPage from './pages/LotteryPage';
import MyTickets from './pages/MyTickets';

const App = () => {
  return (
    <Web3Provider>
      <LotteryProvider>
        <Router>
          <Layout>
            <Routes>
              <Route path="/" element={<Home />} />
              <Route path="/admin" element={<Admin />} />
              <Route path="/lottery/:id" element={<LotteryPage />} />
              <Route path="/my-tickets" element={<MyTickets />} />
            </Routes>
          </Layout>
        </Router>
      </LotteryProvider>
    </Web3Provider>
  );
};

export default App;
