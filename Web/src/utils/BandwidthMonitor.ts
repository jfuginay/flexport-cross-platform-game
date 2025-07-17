export interface BandwidthMetrics {
  bytesIn: number;
  bytesOut: number;
  messagesIn: number;
  messagesOut: number;
  averageBandwidthIn: number; // KB/s
  averageBandwidthOut: number; // KB/s
  peakBandwidthIn: number;
  peakBandwidthOut: number;
  packetLoss: number; // percentage
}

export class BandwidthMonitor {
  private metrics: BandwidthMetrics = {
    bytesIn: 0,
    bytesOut: 0,
    messagesIn: 0,
    messagesOut: 0,
    averageBandwidthIn: 0,
    averageBandwidthOut: 0,
    peakBandwidthIn: 0,
    peakBandwidthOut: 0,
    packetLoss: 0
  };
  
  private history: Array<{
    timestamp: number;
    bytesIn: number;
    bytesOut: number;
  }> = [];
  
  private maxHistorySize = 60; // 1 minute of seconds
  private lastUpdateTime = Date.now();
  private currentSecondBytesIn = 0;
  private currentSecondBytesOut = 0;
  private expectedMessages = new Map<string, number>();
  private receivedMessages = new Map<string, number>();
  
  constructor() {
    // Update metrics every second
    setInterval(() => this.updateMetrics(), 1000);
  }
  
  public recordIncomingMessage(messageSize: number, messageId?: string): void {
    this.metrics.bytesIn += messageSize;
    this.metrics.messagesIn++;
    this.currentSecondBytesIn += messageSize;
    
    if (messageId) {
      this.receivedMessages.set(messageId, Date.now());
    }
  }
  
  public recordOutgoingMessage(messageSize: number, messageId?: string): void {
    this.metrics.bytesOut += messageSize;
    this.metrics.messagesOut++;
    this.currentSecondBytesOut += messageSize;
    
    if (messageId) {
      this.expectedMessages.set(messageId, Date.now());
    }
  }
  
  private updateMetrics(): void {
    const now = Date.now();
    
    // Add current second to history
    this.history.push({
      timestamp: now,
      bytesIn: this.currentSecondBytesIn,
      bytesOut: this.currentSecondBytesOut
    });
    
    // Trim history
    if (this.history.length > this.maxHistorySize) {
      this.history.shift();
    }
    
    // Calculate averages (KB/s)
    if (this.history.length > 0) {
      const totalIn = this.history.reduce((sum, h) => sum + h.bytesIn, 0);
      const totalOut = this.history.reduce((sum, h) => sum + h.bytesOut, 0);
      
      this.metrics.averageBandwidthIn = (totalIn / this.history.length) / 1024;
      this.metrics.averageBandwidthOut = (totalOut / this.history.length) / 1024;
      
      // Update peaks
      const currentInKB = this.currentSecondBytesIn / 1024;
      const currentOutKB = this.currentSecondBytesOut / 1024;
      
      if (currentInKB > this.metrics.peakBandwidthIn) {
        this.metrics.peakBandwidthIn = currentInKB;
      }
      if (currentOutKB > this.metrics.peakBandwidthOut) {
        this.metrics.peakBandwidthOut = currentOutKB;
      }
    }
    
    // Calculate packet loss
    this.calculatePacketLoss();
    
    // Reset current second counters
    this.currentSecondBytesIn = 0;
    this.currentSecondBytesOut = 0;
  }
  
  private calculatePacketLoss(): void {
    const cutoffTime = Date.now() - 5000; // 5 second window
    
    // Clean old entries
    for (const [id, timestamp] of this.expectedMessages) {
      if (timestamp < cutoffTime) {
        this.expectedMessages.delete(id);
      }
    }
    
    for (const [id, timestamp] of this.receivedMessages) {
      if (timestamp < cutoffTime) {
        this.receivedMessages.delete(id);
      }
    }
    
    // Calculate loss rate
    if (this.expectedMessages.size > 0) {
      let lostPackets = 0;
      for (const [id, timestamp] of this.expectedMessages) {
        if (!this.receivedMessages.has(id) && timestamp < Date.now() - 1000) {
          lostPackets++;
        }
      }
      
      this.metrics.packetLoss = (lostPackets / this.expectedMessages.size) * 100;
    } else {
      this.metrics.packetLoss = 0;
    }
  }
  
  public getMetrics(): BandwidthMetrics {
    return { ...this.metrics };
  }
  
  public getBandwidthUsage(): {
    current: number; // KB/s total
    percentage: number; // of 500KB/s target
  } {
    const currentTotal = this.metrics.averageBandwidthIn + this.metrics.averageBandwidthOut;
    const percentage = (currentTotal / 500) * 100; // 500KB/s target
    
    return {
      current: currentTotal,
      percentage: Math.min(percentage, 100)
    };
  }
  
  public reset(): void {
    this.metrics = {
      bytesIn: 0,
      bytesOut: 0,
      messagesIn: 0,
      messagesOut: 0,
      averageBandwidthIn: 0,
      averageBandwidthOut: 0,
      peakBandwidthIn: 0,
      peakBandwidthOut: 0,
      packetLoss: 0
    };
    this.history = [];
    this.expectedMessages.clear();
    this.receivedMessages.clear();
  }
}

// Singleton instance
let bandwidthMonitor: BandwidthMonitor | null = null;

export function getBandwidthMonitor(): BandwidthMonitor {
  if (!bandwidthMonitor) {
    bandwidthMonitor = new BandwidthMonitor();
  }
  return bandwidthMonitor;
}