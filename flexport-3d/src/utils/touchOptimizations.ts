// Touch optimization utilities for mobile

export const initializeTouchOptimizations = () => {
  // Prevent double-tap zoom on iOS
  let lastTouchEnd = 0;
  document.addEventListener('touchend', (e) => {
    const now = Date.now();
    if (now - lastTouchEnd <= 300) {
      e.preventDefault();
    }
    lastTouchEnd = now;
  }, false);

  // Add touch-action CSS to prevent unwanted gestures
  const style = document.createElement('style');
  style.textContent = `
    /* Prevent pull-to-refresh and overscroll bounce */
    body {
      overscroll-behavior: none;
      -webkit-overflow-scrolling: touch;
    }
    
    /* Optimize touch responsiveness */
    button, .clickable, .menu-button, .menu-option {
      touch-action: manipulation;
      -webkit-tap-highlight-color: transparent;
      user-select: none;
    }
    
    /* Prevent text selection on touch */
    .title-screen, .loading-screen, .game-dashboard {
      user-select: none;
      -webkit-user-select: none;
    }
    
    /* Ensure smooth scrolling */
    .scroll-container {
      -webkit-overflow-scrolling: touch;
      scroll-behavior: smooth;
    }
  `;
  document.head.appendChild(style);

  // Add active states for better touch feedback
  document.addEventListener('touchstart', (e) => {
    const target = e.target as HTMLElement;
    if (target.matches('button, .clickable, .menu-button, .menu-option')) {
      target.classList.add('touch-active');
    }
  });

  document.addEventListener('touchend', (e) => {
    const target = e.target as HTMLElement;
    if (target.matches('button, .clickable, .menu-button, .menu-option')) {
      setTimeout(() => {
        target.classList.remove('touch-active');
      }, 150);
    }
  });
};

// Detect if device supports touch
export const isTouchDevice = () => {
  return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
};

// Optimize for mobile performance
export const optimizeMobilePerformance = () => {
  if (isTouchDevice()) {
    // Reduce particle effects on mobile
    document.body.classList.add('mobile-device');
    
    // Enable GPU acceleration for transforms
    const elements = document.querySelectorAll('.ship, .particle, .wave');
    elements.forEach(el => {
      (el as HTMLElement).style.willChange = 'transform';
    });
  }
};