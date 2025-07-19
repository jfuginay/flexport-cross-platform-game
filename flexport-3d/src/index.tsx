import React from 'react';
import ReactDOM from 'react-dom/client';
import 'mapbox-gl/dist/mapbox-gl.css';
import './index.css';
import App from './App';

// Suppress console errors in production
if (process.env.NODE_ENV === 'production') {
  console.error = () => {};
  console.warn = () => {};
  // Optional: Keep console.log for debugging
  // console.log = () => {};
}

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
