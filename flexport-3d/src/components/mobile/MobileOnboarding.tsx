// @ts-nocheck
import React, { useState } from 'react';
import './MobileOnboarding.css';

interface MobileOnboardingProps {
  onComplete: () => void;
}

export const MobileOnboarding: React.FC<MobileOnboardingProps> = ({ onComplete }) => {
  const [currentStep, setCurrentStep] = useState(0);
  
  const steps = [
    {
      title: 'Welcome to FlexPort 3D',
      description: 'Build your global shipping empire',
      icon: '🚢',
      image: '/onboarding/globe.png'
    },
    {
      title: 'Manage Your Fleet',
      description: 'Buy ships and optimize cargo capacity',
      icon: '⚓',
      image: '/onboarding/fleet.png'
    },
    {
      title: 'Accept Contracts',
      description: 'Choose profitable routes across the globe',
      icon: '📦',
      image: '/onboarding/contracts.png'
    },
    {
      title: 'Track Everything',
      description: 'Monitor your ships in real-time',
      icon: '📍',
      image: '/onboarding/tracking.png'
    }
  ];
  
  const handleNext = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep(currentStep + 1);
    } else {
      onComplete();
    }
  };
  
  const handleSkip = () => {
    onComplete();
  };
  
  return (
    <div className="mobile-onboarding">
      <button className="skip-button" onClick={handleSkip}>
        Skip
      </button>
      
      <div className="onboarding-content">
        <div className="step-icon">
          {steps[currentStep].icon}
        </div>
        
        <h1 className="step-title">
          {steps[currentStep].title}
        </h1>
        
        <p className="step-description">
          {steps[currentStep].description}
        </p>
        
        <div className="step-indicators">
          {steps.map((_, index) => (
            <div
              key={index}
              className={`indicator ${index === currentStep ? 'active' : ''} ${index < currentStep ? 'completed' : ''}`}
            />
          ))}
        </div>
      </div>
      
      <button className="next-button" onClick={handleNext}>
        {currentStep === steps.length - 1 ? 'Get Started' : 'Next'}
      </button>
    </div>
  );
};