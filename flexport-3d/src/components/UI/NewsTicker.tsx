import React, { useState, useEffect } from 'react';
import './NewsTicker.css';

interface NewsItem {
  id: string;
  message: string;
  type: 'info' | 'warning' | 'alert' | 'success';
  timestamp: Date;
  location?: { lat: number; lng: number };
}

interface NewsTickerProps {
  onNewsClick?: (item: NewsItem) => void;
}

export const NewsTicker: React.FC<NewsTickerProps> = ({ onNewsClick }) => {
  const [newsItems, setNewsItems] = useState<NewsItem[]>([
    {
      id: '1',
      message: 'Welcome to FlexPort Global! Start by purchasing your first ship.',
      type: 'info',
      timestamp: new Date(),
    },
  ]);
  const [isVisible, setIsVisible] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);

  // Rotate through news items
  useEffect(() => {
    if (newsItems.length === 0) return;
    
    const interval = setInterval(() => {
      setCurrentIndex((prev) => (prev + 1) % newsItems.length);
    }, 5000); // Change news every 5 seconds

    return () => clearInterval(interval);
  }, [newsItems.length]);

  // Simulate news events
  useEffect(() => {
    const newsEvents = [
      { message: 'Storm warning in the North Atlantic! Ships advised to seek shelter.', type: 'warning' as const },
      { message: 'New trade route opened between Singapore and Rotterdam!', type: 'success' as const },
      { message: 'Piracy alert near Somalia coast. Increase security measures.', type: 'alert' as const },
      { message: 'Port of Los Angeles reports record cargo throughput this quarter.', type: 'info' as const },
      { message: 'Fuel prices drop 15% - great time to expand your fleet!', type: 'success' as const },
    ];

    const addRandomNews = () => {
      const randomEvent = newsEvents[Math.floor(Math.random() * newsEvents.length)];
      const newItem: NewsItem = {
        id: Date.now().toString(),
        ...randomEvent,
        timestamp: new Date(),
      };
      
      setNewsItems(prev => [...prev.slice(-4), newItem]); // Keep last 5 items
    };

    const interval = setInterval(addRandomNews, 30000); // Add news every 30 seconds

    return () => clearInterval(interval);
  }, []);

  if (!isVisible || newsItems.length === 0) return null;

  const currentItem = newsItems[currentIndex];

  return (
    <div className="news-ticker">
      <div className="ticker-controls">
        <button 
          className="ticker-toggle"
          onClick={() => setIsVisible(false)}
          title="Hide news ticker"
        >
          ✕
        </button>
      </div>
      
      <div className="ticker-content">
        <span className="ticker-label">📰 NEWS</span>
        <div 
          className={`ticker-message ${currentItem.type}`}
          onClick={() => onNewsClick?.(currentItem)}
          style={{ cursor: currentItem.location ? 'pointer' : 'default' }}
        >
          {currentItem.message}
          {currentItem.location && <span className="click-hint"> (click to view)</span>}
        </div>
      </div>
      
      <div className="ticker-dots">
        {newsItems.map((_, index) => (
          <span 
            key={index}
            className={`dot ${index === currentIndex ? 'active' : ''}`}
          />
        ))}
      </div>
    </div>
  );
};