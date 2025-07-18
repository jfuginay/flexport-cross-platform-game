import React, { useState } from 'react';
import '../styles/ResearchTab.css';

export const ResearchTab: React.FC = () => {
  const [apiKey, setApiKey] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [question, setQuestion] = useState('');
  const [messages, setMessages] = useState<{ role: 'user' | 'assistant'; content: string }[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const handleConnect = () => {
    if (apiKey.trim()) {
      localStorage.setItem('anthropic_api_key', apiKey);
      setIsConnected(true);
    }
  };

  const handleDisconnect = () => {
    localStorage.removeItem('anthropic_api_key');
    setApiKey('');
    setIsConnected(false);
    setMessages([]);
  };

  const askClaude = async () => {
    if (!question.trim() || !isConnected) return;

    const newMessages = [...messages, { role: 'user' as const, content: question }];
    setMessages(newMessages);
    setQuestion('');
    setIsLoading(true);

    try {
      const savedApiKey = localStorage.getItem('anthropic_api_key');
      
      // Note: Direct API calls to Anthropic from browser are not recommended for production
      // This is a simplified example. In production, use a backend proxy
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': savedApiKey || '',
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify({
          model: 'claude-3-sonnet-20240229',
          messages: newMessages.map(m => ({
            role: m.role,
            content: m.content
          })),
          max_tokens: 1000,
          temperature: 0.7,
          system: "You are a helpful logistics and shipping industry expert assistant. Provide concise, actionable advice about shipping, logistics, supply chain management, and the shipping game the user is playing."
        })
      });

      if (!response.ok) {
        throw new Error('Failed to get response from Claude');
      }

      const data = await response.json();
      setMessages([...newMessages, { role: 'assistant', content: data.content[0].text }]);
    } catch (error) {
      console.error('Error calling Claude API:', error);
      setMessages([...newMessages, { 
        role: 'assistant', 
        content: 'Sorry, I encountered an error. Please check your API key or try again later. For security reasons, consider using a backend proxy for API calls in production.'
      }]);
    } finally {
      setIsLoading(false);
    }
  };

  const suggestedQuestions = [
    "What are the most profitable shipping routes globally?",
    "How can I optimize my fleet efficiency?",
    "What factors affect shipping contract pricing?",
    "Explain different types of cargo and their requirements",
    "What are the best practices for fleet management?",
    "How do weather patterns affect shipping routes?"
  ];

  return (
    <div className="research-tab">
      <h2>Research Assistant</h2>
      
      {!isConnected ? (
        <div className="api-setup">
          <h3>Connect to Claude</h3>
          <p>Enter your Anthropic API key to enable AI-powered research assistance.</p>
          <div className="api-input-group">
            <input
              type="password"
              placeholder="Enter your Anthropic API key"
              value={apiKey}
              onChange={(e) => setApiKey(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleConnect()}
            />
            <button onClick={handleConnect} disabled={!apiKey.trim()}>
              Connect
            </button>
          </div>
          <p className="api-note">
            Get your API key from <a href="https://console.anthropic.com" target="_blank" rel="noopener noreferrer">console.anthropic.com</a>
          </p>
          <div className="security-note">
            ⚠️ Note: For production use, API calls should be made through a secure backend to protect your API key.
          </div>
        </div>
      ) : (
        <div className="chat-interface">
          <div className="chat-header">
            <h3>Ask Claude about Logistics & Shipping</h3>
            <button onClick={handleDisconnect} className="disconnect-btn">
              Disconnect
            </button>
          </div>
          
          <div className="messages-container">
            {messages.length === 0 ? (
              <div className="welcome-message">
                <p>Welcome to your AI Research Assistant!</p>
                <p>Ask me anything about shipping, logistics, or strategies for your game.</p>
                <div className="suggested-questions">
                  <h4>Suggested questions:</h4>
                  {suggestedQuestions.map((q, idx) => (
                    <button
                      key={idx}
                      className="suggestion-btn"
                      onClick={() => setQuestion(q)}
                    >
                      {q}
                    </button>
                  ))}
                </div>
              </div>
            ) : (
              messages.map((msg, idx) => (
                <div key={idx} className={`message ${msg.role}`}>
                  <div className="message-header">{msg.role === 'user' ? 'You' : 'Claude'}</div>
                  <div className="message-content">{msg.content}</div>
                </div>
              ))
            )}
            {isLoading && (
              <div className="message assistant loading">
                <div className="message-header">Claude</div>
                <div className="message-content">
                  <span className="typing-indicator">●●●</span>
                </div>
              </div>
            )}
          </div>
          
          <div className="input-area">
            <input
              type="text"
              placeholder="Ask a question..."
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && !isLoading && askClaude()}
              disabled={isLoading}
            />
            <button onClick={askClaude} disabled={!question.trim() || isLoading}>
              {isLoading ? 'Thinking...' : 'Send'}
            </button>
          </div>
        </div>
      )}
    </div>
  );
};