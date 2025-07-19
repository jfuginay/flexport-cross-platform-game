// @ts-nocheck
import React, { useEffect } from 'react';
import { toast, ToastContainer } from 'react-toastify';
import { useGameStore } from '../../store/gameStore';
import { ShipStatus } from '../../types/game.types';
import 'react-toastify/dist/ReactToastify.css';
import './Toast.css';

export const NotificationSystem: React.FC = () => {
  const { fleet, contracts } = useGameStore();
  
  useEffect(() => {
    // Monitor ship arrivals
    const checkShipArrivals = () => {
      fleet.forEach(ship => {
        if (ship.status === ShipStatus.IDLE && ship.destination === null) {
          // Ship has just arrived
          toast.info(`🚢 ${ship.name} has arrived at destination`, {
            position: "bottom-left",
            autoClose: 3000,
          });
        }
      });
    };
    
    const interval = setInterval(checkShipArrivals, 2000);
    return () => clearInterval(interval);
  }, [fleet]);
  
  useEffect(() => {
    // Monitor contract completions
    contracts.forEach(contract => {
      if (contract.status === 'COMPLETED') {
        toast.success(`✅ Contract completed! Earned ${contract.value.toLocaleString()}`, {
          position: "bottom-left",
          autoClose: 5000,
        });
      }
    });
  }, [contracts]);
  
  return (
    <ToastContainer
      theme="dark"
      style={{
        fontSize: '14px'
      }}
    />
  );
};