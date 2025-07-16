import { v4 as uuidv4 } from 'uuid';
import { 
  WebSocketMessage, 
  MessageType, 
  MultiplayerPlayer, 
  GameRoom,
  MultiplayerState
} from '@/types';

export type WebSocketEventCallback = (message: WebSocketMessage) => void;

export class WebSocketManager {
  private ws: WebSocket | null = null;
  private url: string;
  private playerId: string;
  private eventCallbacks: Map<MessageType, WebSocketEventCallback[]> = new Map();
  private connectionCallbacks: Set<(connected: boolean) => void> = new Set();
  private isConnecting = false;
  private reconnectTimer: number | null = null;
  private heartbeatTimer: number | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000; // Start with 1 second
  private maxReconnectDelay = 30000; // Max 30 seconds
  private heartbeatInterval = 30000; // 30 seconds
  private messageQueue: WebSocketMessage[] = [];
  private pendingMessages: Map<string, { resolve: Function; reject: Function; timeout: number }> = new Map();

  constructor(url: string = 'ws://localhost:8080') {
    this.url = url;
    this.playerId = this.generatePlayerId();
    this.setupMessageTypes();
  }

  private generatePlayerId(): string {
    // Try to get existing player ID from localStorage
    let playerId = localStorage.getItem('flexport_player_id');
    if (!playerId) {
      playerId = uuidv4();
      localStorage.setItem('flexport_player_id', playerId);
    }
    return playerId;
  }

  private setupMessageTypes(): void {
    const messageTypes: MessageType[] = [
      'player_join', 'player_leave', 'player_ready', 'room_update',
      'game_start', 'game_action', 'game_state_sync', 'heartbeat',
      'error', 'room_list', 'create_room', 'join_room', 'leave_room'
    ];

    messageTypes.forEach(type => {
      this.eventCallbacks.set(type, []);
    });
  }

  public getPlayerId(): string {
    return this.playerId;
  }

  public isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }

  public async connect(): Promise<boolean> {
    if (this.isConnecting || this.isConnected()) {
      return this.isConnected();
    }

    this.isConnecting = true;

    try {
      console.log(`Connecting to WebSocket server at ${this.url}...`);
      
      this.ws = new WebSocket(this.url);
      
      return new Promise((resolve) => {
        if (!this.ws) {
          resolve(false);
          return;
        }

        const timeout = setTimeout(() => {
          this.ws?.close();
          resolve(false);
        }, 10000); // 10 second timeout

        this.ws.onopen = () => {
          clearTimeout(timeout);
          this.isConnecting = false;
          this.reconnectAttempts = 0;
          console.log('WebSocket connected successfully');
          this.startHeartbeat();
          this.flushMessageQueue();
          this.notifyConnectionCallbacks(true);
          resolve(true);
        };

        this.ws.onclose = (event) => {
          clearTimeout(timeout);
          this.isConnecting = false;
          console.log('WebSocket connection closed:', event.code, event.reason);
          this.stopHeartbeat();
          this.notifyConnectionCallbacks(false);
          
          if (!event.wasClean && this.reconnectAttempts < this.maxReconnectAttempts) {
            this.scheduleReconnect();
          }
          
          resolve(false);
        };

        this.ws.onerror = (error) => {
          clearTimeout(timeout);
          this.isConnecting = false;
          console.error('WebSocket error:', error);
          resolve(false);
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event);
        };
      });
    } catch (error) {
      this.isConnecting = false;
      console.error('Failed to create WebSocket connection:', error);
      return false;
    }
  }

  public disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.stopHeartbeat();

    if (this.ws) {
      this.ws.close(1000, 'Client disconnect');
      this.ws = null;
    }

    this.notifyConnectionCallbacks(false);
  }

  public async sendMessage(type: MessageType, payload: any, roomId?: string): Promise<void> {
    const message: WebSocketMessage = {
      type,
      payload,
      playerId: this.playerId,
      roomId,
      timestamp: Date.now(),
      messageId: uuidv4()
    };

    if (!this.isConnected()) {
      // Queue message for when connection is restored
      this.messageQueue.push(message);
      throw new Error('WebSocket not connected. Message queued for retry.');
    }

    try {
      this.ws!.send(JSON.stringify(message));
    } catch (error) {
      console.error('Failed to send message:', error);
      this.messageQueue.push(message);
      throw error;
    }
  }

  public async sendMessageWithResponse(type: MessageType, payload: any, roomId?: string, timeout: number = 5000): Promise<any> {
    const message: WebSocketMessage = {
      type,
      payload,
      playerId: this.playerId,
      roomId,
      timestamp: Date.now(),
      messageId: uuidv4()
    };

    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        this.pendingMessages.delete(message.messageId);
        reject(new Error('Message timeout'));
      }, timeout);

      this.pendingMessages.set(message.messageId, {
        resolve,
        reject,
        timeout: timeoutId
      });

      this.sendMessage(type, payload, roomId).catch(reject);
    });
  }

  public onMessage(type: MessageType, callback: WebSocketEventCallback): () => void {
    const callbacks = this.eventCallbacks.get(type);
    if (callbacks) {
      callbacks.push(callback);
    }

    // Return unsubscribe function
    return () => {
      const callbacks = this.eventCallbacks.get(type);
      if (callbacks) {
        const index = callbacks.indexOf(callback);
        if (index > -1) {
          callbacks.splice(index, 1);
        }
      }
    };
  }

  public onConnectionChange(callback: (connected: boolean) => void): () => void {
    this.connectionCallbacks.add(callback);
    
    // Return unsubscribe function
    return () => {
      this.connectionCallbacks.delete(callback);
    };
  }

  private handleMessage(event: MessageEvent): void {
    try {
      const message: WebSocketMessage = JSON.parse(event.data);
      
      // Handle response to pending message
      if (message.messageId && this.pendingMessages.has(message.messageId)) {
        const pending = this.pendingMessages.get(message.messageId)!;
        clearTimeout(pending.timeout);
        this.pendingMessages.delete(message.messageId);
        pending.resolve(message.payload);
        return;
      }

      // Handle heartbeat
      if (message.type === 'heartbeat') {
        this.sendMessage('heartbeat', { playerId: this.playerId });
        return;
      }

      // Dispatch to registered callbacks
      const callbacks = this.eventCallbacks.get(message.type);
      if (callbacks) {
        callbacks.forEach(callback => {
          try {
            callback(message);
          } catch (error) {
            console.error(`Error in message callback for ${message.type}:`, error);
          }
        });
      }
    } catch (error) {
      console.error('Failed to parse WebSocket message:', error);
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = window.setInterval(() => {
      if (this.isConnected()) {
        this.sendMessage('heartbeat', { playerId: this.playerId }).catch(error => {
          console.warn('Heartbeat failed:', error);
        });
      }
    }, this.heartbeatInterval);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
    }

    this.reconnectAttempts++;
    const delay = Math.min(this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1), this.maxReconnectDelay);
    
    console.log(`Scheduling reconnect attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts} in ${delay}ms`);
    
    this.reconnectTimer = window.setTimeout(() => {
      this.connect().catch(error => {
        console.error('Reconnect failed:', error);
      });
    }, delay);
  }

  private flushMessageQueue(): void {
    if (this.messageQueue.length === 0) return;

    console.log(`Flushing ${this.messageQueue.length} queued messages`);
    const messages = [...this.messageQueue];
    this.messageQueue = [];

    messages.forEach(message => {
      if (this.isConnected()) {
        try {
          this.ws!.send(JSON.stringify(message));
        } catch (error) {
          console.error('Failed to send queued message:', error);
          this.messageQueue.push(message);
        }
      } else {
        this.messageQueue.push(message);
      }
    });
  }

  private notifyConnectionCallbacks(connected: boolean): void {
    this.connectionCallbacks.forEach(callback => {
      try {
        callback(connected);
      } catch (error) {
        console.error('Error in connection callback:', error);
      }
    });
  }

  // Convenience methods for common operations
  public async createRoom(roomName: string, settings: any): Promise<GameRoom> {
    const response = await this.sendMessageWithResponse('create_room', {
      name: roomName,
      settings
    });
    return response.room;
  }

  public async joinRoom(roomId: string, password?: string): Promise<GameRoom> {
    const response = await this.sendMessageWithResponse('join_room', {
      roomId,
      password
    });
    return response.room;
  }

  public async leaveRoom(): Promise<void> {
    await this.sendMessage('leave_room', {});
  }

  public async setReady(isReady: boolean): Promise<void> {
    await this.sendMessage('player_ready', { isReady });
  }

  public async getRoomList(): Promise<GameRoom[]> {
    const response = await this.sendMessageWithResponse('room_list', {});
    return response.rooms;
  }

  public getConnectionStats(): {
    isConnected: boolean;
    playerId: string;
    reconnectAttempts: number;
    queuedMessages: number;
  } {
    return {
      isConnected: this.isConnected(),
      playerId: this.playerId,
      reconnectAttempts: this.reconnectAttempts,
      queuedMessages: this.messageQueue.length
    };
  }
}