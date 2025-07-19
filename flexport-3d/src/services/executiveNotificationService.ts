interface SecureMessage {
  id: string;
  timestamp: Date;
  sender: string;
  senderTitle: string;
  priority: 'URGENT' | 'HIGH' | 'MEDIUM';
  encrypted: boolean;
  subject: string;
  message: string;
  requiresAction: boolean;
  actions?: Array<{
    label: string;
    action: string;
    consequence?: string;
  }>;
  expiresAt?: Date;
}

interface ExecutiveAlert {
  type: 'UNION_CRISIS' | 'PORT_STRIKE' | 'REGULATORY_CHANGE' | 'MARKET_CRASH' | 'SECURITY_BREACH';
  severity: 'CRITICAL' | 'HIGH' | 'MEDIUM';
  affectedRoutes?: string[];
  financialImpact?: number;
  timeToRespond?: number; // minutes
}

class ExecutiveNotificationService {
  private messages: SecureMessage[] = [];
  private subscribers: ((message: SecureMessage) => void)[] = [];
  private audioAlert: HTMLAudioElement;

  constructor() {
    this.audioAlert = new Audio('/sounds/secure-message.mp3');
    this.audioAlert.volume = 0.7;
  }

  public sendSecureMessage(alert: ExecutiveAlert, content: any): SecureMessage {
    const message: SecureMessage = {
      id: `SEC-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
      sender: this.getSenderForAlert(alert.type),
      senderTitle: this.getSenderTitleForAlert(alert.type),
      priority: alert.severity === 'CRITICAL' ? 'URGENT' : alert.severity,
      encrypted: true,
      subject: this.getSubjectForAlert(alert.type),
      message: content.message || this.getDefaultMessage(alert.type),
      requiresAction: alert.severity === 'CRITICAL',
      actions: content.actions,
      expiresAt: alert.timeToRespond ? new Date(Date.now() + alert.timeToRespond * 60000) : undefined
    };

    this.messages.unshift(message);
    this.notifySubscribers(message);
    
    if (alert.severity === 'CRITICAL') {
      this.playSecureAlert();
    }

    return message;
  }

  private getSenderForAlert(type: string): string {
    const senders = {
      'UNION_CRISIS': 'Labor Relations Director',
      'PORT_STRIKE': 'Port Operations Chief',
      'REGULATORY_CHANGE': 'Chief Compliance Officer',
      'MARKET_CRASH': 'Chief Financial Officer',
      'SECURITY_BREACH': 'Chief Security Officer'
    };
    return senders[type] || 'Executive Assistant';
  }

  private getSenderTitleForAlert(type: string): string {
    const titles = {
      'UNION_CRISIS': 'Harold Daggett Situation Room',
      'PORT_STRIKE': 'Emergency Operations Center',
      'REGULATORY_CHANGE': 'Regulatory Affairs',
      'MARKET_CRASH': 'Financial Crisis Team',
      'SECURITY_BREACH': 'Security Operations Center'
    };
    return titles[type] || 'Executive Office';
  }

  private getSubjectForAlert(type: string): string {
    const subjects = {
      'UNION_CRISIS': '🚨 URGENT: Union Negotiation Crisis',
      'PORT_STRIKE': '🚨 CRITICAL: Port Operations Disrupted',
      'REGULATORY_CHANGE': '⚠️ Regulatory Compliance Alert',
      'MARKET_CRASH': '📉 Market Emergency',
      'SECURITY_BREACH': '🔒 Security Incident Detected'
    };
    return subjects[type] || 'Executive Alert';
  }

  private getDefaultMessage(type: string): string {
    const messages = {
      'UNION_CRISIS': 'Union leadership is demanding immediate negotiations. Disruption to operations imminent.',
      'PORT_STRIKE': 'Port workers have initiated strike action. Multiple terminals affected.',
      'REGULATORY_CHANGE': 'New regulations require immediate compliance review.',
      'MARKET_CRASH': 'Significant market volatility detected. Portfolio review required.',
      'SECURITY_BREACH': 'Unauthorized access detected in critical systems.'
    };
    return messages[type] || 'Immediate executive attention required.';
  }

  public subscribe(callback: (message: SecureMessage) => void): () => void {
    this.subscribers.push(callback);
    return () => {
      this.subscribers = this.subscribers.filter(sub => sub !== callback);
    };
  }

  private notifySubscribers(message: SecureMessage): void {
    this.subscribers.forEach(callback => callback(message));
  }

  private playSecureAlert(): void {
    this.audioAlert.play().catch(e => console.log('Audio play failed:', e));
  }

  public getMessages(): SecureMessage[] {
    return this.messages;
  }

  public markAsRead(messageId: string): void {
    const message = this.messages.find(m => m.id === messageId);
    if (message) {
      // Mark as read logic
    }
  }

  public respondToMessage(messageId: string, action: string): void {
    const message = this.messages.find(m => m.id === messageId);
    if (message && message.actions) {
      const selectedAction = message.actions.find(a => a.action === action);
      if (selectedAction) {
        // Execute the action
        this.executeAction(message, selectedAction);
      }
    }
  }

  private executeAction(message: SecureMessage, action: any): void {
    // Import crisisEventService dynamically to avoid circular dependency
    import('./crisisEventService').then(({ crisisEventService }) => {
      // Find the crisis event by matching the message ID
      const crisisId = message.id.replace('SEC-', 'CRISIS-');
      crisisEventService.resolveCrisis(crisisId, action.action);
    });
  }
}

export const executiveNotificationService = new ExecutiveNotificationService();
export type { SecureMessage, ExecutiveAlert };