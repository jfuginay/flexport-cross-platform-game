import { GameRoom, MultiplayerPlayer, GameRoomSettings } from '@/types';
import { MultiplayerSystem } from '@/systems/MultiplayerSystem';

export class LobbyComponent {
  private element: HTMLElement;
  private multiplayerSystem: MultiplayerSystem;
  private isVisible = false;
  private refreshInterval: number | null = null;
  private eventListeners: (() => void)[] = [];
  private onHideCallback?: () => void;

  constructor(multiplayerSystem: MultiplayerSystem) {
    this.multiplayerSystem = multiplayerSystem;
    this.element = this.createElement();
    this.setupEventListeners();
    this.hide(); // Start hidden
  }

  private createElement(): HTMLElement {
    const element = document.createElement('div');
    element.className = 'lobby-component';
    element.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: linear-gradient(135deg, rgba(15, 23, 42, 0.95), rgba(30, 41, 59, 0.95));
      backdrop-filter: blur(20px);
      z-index: 1000;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: white;
      animation: fadeIn 0.3s ease-out;
    `;

    element.innerHTML = this.getInitialHTML();
    document.body.appendChild(element);
    
    this.setupButtonHandlers(element);
    return element;
  }

  private getInitialHTML(): string {
    return `
      <div class="lobby-container" style="
        width: 90%;
        max-width: 1200px;
        height: 80%;
        max-height: 800px;
        background: linear-gradient(135deg, rgba(15, 23, 42, 0.98), rgba(30, 41, 59, 0.98));
        border: 2px solid rgba(59, 130, 246, 0.5);
        border-radius: 20px;
        padding: 32px;
        box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
        display: flex;
        flex-direction: column;
        gap: 24px;
        overflow: hidden;
      ">
        <!-- Header -->
        <div class="lobby-header" style="
          display: flex;
          align-items: center;
          justify-content: space-between;
          border-bottom: 1px solid rgba(59, 130, 246, 0.3);
          padding-bottom: 16px;
        ">
          <div>
            <h1 style="margin: 0; font-size: 28px; background: linear-gradient(135deg, #3b82f6, #8b5cf6); -webkit-background-clip: text; -webkit-text-fill-color: transparent;">
              🚢 FlexPort Multiplayer
            </h1>
            <div class="connection-status" style="
              margin-top: 8px;
              font-size: 14px;
              display: flex;
              align-items: center;
              gap: 8px;
            ">
              <div class="status-indicator" style="
                width: 8px;
                height: 8px;
                border-radius: 50%;
                background: #ef4444;
              "></div>
              <span>Connecting...</span>
            </div>
          </div>
          <button class="close-btn btn" style="
            background: rgba(239, 68, 68, 0.8);
            border: none;
            padding: 8px 16px;
            border-radius: 6px;
            color: white;
            cursor: pointer;
            font-size: 14px;
          ">Close</button>
        </div>

        <!-- Main Content -->
        <div class="lobby-content" style="
          flex: 1;
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 24px;
          overflow: hidden;
        ">
          <!-- Room List -->
          <div class="room-list-section" style="
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid rgba(59, 130, 246, 0.3);
            border-radius: 12px;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 16px;
          ">
            <div style="display: flex; align-items: center; justify-content: space-between;">
              <h2 style="margin: 0; font-size: 20px; color: #3b82f6;">Available Rooms</h2>
              <button class="refresh-rooms-btn btn btn-secondary" style="
                padding: 6px 12px;
                font-size: 12px;
              ">Refresh</button>
            </div>
            
            <div class="room-list" style="
              flex: 1;
              overflow-y: auto;
              display: flex;
              flex-direction: column;
              gap: 8px;
              min-height: 200px;
            ">
              <div class="loading-rooms" style="
                display: flex;
                align-items: center;
                justify-content: center;
                height: 100px;
                color: #64748b;
                font-style: italic;
              ">
                Loading rooms...
              </div>
            </div>

            <button class="create-room-btn btn btn-primary" style="
              margin-top: auto;
            ">Create New Room</button>
          </div>

          <!-- Current Room / Room Creation -->
          <div class="room-section" style="
            background: rgba(15, 23, 42, 0.6);
            border: 1px solid rgba(59, 130, 246, 0.3);
            border-radius: 12px;
            padding: 20px;
            display: flex;
            flex-direction: column;
            gap: 16px;
          ">
            <div class="room-content">
              ${this.getWelcomeHTML()}
            </div>
          </div>
        </div>
      </div>

      <!-- Create Room Modal -->
      <div class="create-room-modal" style="
        position: absolute;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background: linear-gradient(135deg, rgba(15, 23, 42, 0.98), rgba(30, 41, 59, 0.98));
        border: 2px solid rgba(59, 130, 246, 0.5);
        border-radius: 16px;
        padding: 24px;
        width: 400px;
        box-shadow: 0 25px 50px rgba(0, 0, 0, 0.5);
        display: none;
      ">
        <h3 style="margin: 0 0 20px 0; color: #3b82f6;">Create New Room</h3>
        
        <div style="display: flex; flex-direction: column; gap: 16px;">
          <div>
            <label style="display: block; margin-bottom: 8px; color: #cbd5e1;">Room Name</label>
            <input class="room-name-input" type="text" placeholder="Enter room name..." style="
              width: 100%;
              padding: 8px 12px;
              background: rgba(30, 41, 59, 0.8);
              border: 1px solid rgba(59, 130, 246, 0.3);
              border-radius: 6px;
              color: white;
              font-size: 14px;
            ">
          </div>

          <div>
            <label style="display: block; margin-bottom: 8px; color: #cbd5e1;">Max Players</label>
            <select class="max-players-select" style="
              width: 100%;
              padding: 8px 12px;
              background: rgba(30, 41, 59, 0.8);
              border: 1px solid rgba(59, 130, 246, 0.3);
              border-radius: 6px;
              color: white;
              font-size: 14px;
            ">
              <option value="2">2 Players</option>
              <option value="3">3 Players</option>
              <option value="4" selected>4 Players</option>
            </select>
          </div>

          <div style="display: flex; align-items: center; gap: 8px;">
            <input class="private-room-checkbox" type="checkbox" id="private-room">
            <label for="private-room" style="color: #cbd5e1; font-size: 14px;">Private Room</label>
          </div>

          <div style="display: flex; gap: 12px; margin-top: 8px;">
            <button class="confirm-create-btn btn btn-primary" style="flex: 1;">Create Room</button>
            <button class="cancel-create-btn btn btn-secondary" style="flex: 1;">Cancel</button>
          </div>
        </div>
      </div>
    `;
  }

  private getWelcomeHTML(): string {
    return `
      <div style="
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100%;
        text-align: center;
        gap: 20px;
      ">
        <div style="font-size: 64px;">🌊</div>
        <h3 style="margin: 0; color: #3b82f6;">Welcome to Multiplayer</h3>
        <p style="margin: 0; color: #64748b; line-height: 1.6;">
          Create a new room or join an existing one to start playing with friends.
          Build your logistics empire together!
        </p>
      </div>
    `;
  }

  private getRoomHTML(room: GameRoom): string {
    const playerCount = room.players.length;
    const statusColor = room.status === 'waiting' ? '#10b981' : 
                       room.status === 'starting' ? '#f59e0b' : '#64748b';
    
    return `
      <div class="room-item" data-room-id="${room.id}" style="
        background: rgba(30, 41, 59, 0.6);
        border: 1px solid rgba(59, 130, 246, 0.2);
        border-radius: 8px;
        padding: 16px;
        cursor: pointer;
        transition: all 0.2s ease;
        hover:border-color: rgba(59, 130, 246, 0.5);
      ">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px;">
          <h4 style="margin: 0; color: white; font-size: 16px;">${room.name}</h4>
          <div style="
            background: ${statusColor};
            color: white;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 12px;
            text-transform: capitalize;
          ">${room.status}</div>
        </div>
        
        <div style="display: flex; align-items: center; justify-content: space-between; color: #94a3b8; font-size: 14px;">
          <span>👥 ${playerCount}/${room.maxPlayers} players</span>
          <span>🎮 ${room.gameMode}</span>
        </div>
        
        ${room.settings.privateRoom ? '<div style="color: #f59e0b; font-size: 12px; margin-top: 4px;">🔒 Private</div>' : ''}
      </div>
    `;
  }

  private getCurrentRoomHTML(room: GameRoom, currentPlayer: MultiplayerPlayer): string {
    const isHost = currentPlayer.isHost;
    const allReady = room.players.every(p => p.isReady);
    const canStart = isHost && room.players.length >= 2 && allReady;

    return `
      <div style="height: 100%; display: flex; flex-direction: column;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 20px;">
          <h3 style="margin: 0; color: #3b82f6;">${room.name}</h3>
          <button class="leave-room-btn btn btn-secondary" style="font-size: 12px; padding: 6px 12px;">
            Leave Room
          </button>
        </div>

        <div style="flex: 1; display: flex; flex-direction: column; gap: 16px;">
          <div>
            <h4 style="margin: 0 0 12px 0; color: #cbd5e1;">Players (${room.players.length}/${room.maxPlayers})</h4>
            <div class="player-list" style="
              display: flex;
              flex-direction: column;
              gap: 8px;
              max-height: 200px;
              overflow-y: auto;
            ">
              ${room.players.map(player => this.getPlayerHTML(player)).join('')}
            </div>
          </div>

          <div style="margin-top: auto;">
            <div style="
              background: rgba(30, 41, 59, 0.6);
              border: 1px solid rgba(59, 130, 246, 0.3);
              border-radius: 8px;
              padding: 16px;
              margin-bottom: 16px;
            ">
              <h5 style="margin: 0 0 8px 0; color: #cbd5e1;">Game Settings</h5>
              <div style="font-size: 14px; color: #94a3b8; line-height: 1.4;">
                • Mode: ${room.gameMode}<br>
                • Starting Cash: $${room.settings.startingCash.toLocaleString()}<br>
                • Max Turns: ${room.settings.maxTurns}
              </div>
            </div>

            <div style="display: flex; gap: 12px;">
              <button class="ready-btn btn ${currentPlayer.isReady ? 'btn-secondary' : 'btn-primary'}" style="flex: 1;">
                ${currentPlayer.isReady ? '✓ Ready' : 'Ready Up'}
              </button>
              ${isHost ? `
                <button class="start-game-btn btn ${canStart ? 'btn-primary' : 'btn-secondary'}" 
                        style="flex: 1; ${!canStart ? 'opacity: 0.5; cursor: not-allowed;' : ''}" 
                        ${!canStart ? 'disabled' : ''}>
                  Start Game
                </button>
              ` : ''}
            </div>
          </div>
        </div>
      </div>
    `;
  }

  private getPlayerHTML(player: MultiplayerPlayer): string {
    const statusIcon = player.connectionStatus === 'connected' ? '🟢' : 
                      player.connectionStatus === 'reconnecting' ? '🟡' : '🔴';
    
    return `
      <div style="
        display: flex;
        align-items: center;
        justify-content: space-between;
        background: rgba(30, 41, 59, 0.4);
        border: 1px solid rgba(59, 130, 246, 0.2);
        border-radius: 6px;
        padding: 12px;
      ">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div style="
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: ${player.color};
          "></div>
          <span style="color: white; font-weight: 500;">
            ${player.name}
            ${player.isHost ? ' 👑' : ''}
          </span>
        </div>
        
        <div style="display: flex; align-items: center; gap: 8px; font-size: 14px;">
          <span>${statusIcon}</span>
          ${player.isReady ? '<span style="color: #10b981;">Ready</span>' : '<span style="color: #64748b;">Not Ready</span>'}
        </div>
      </div>
    `;
  }

  private setupEventListeners(): void {
    // Connection status updates
    const unsubConnection = this.multiplayerSystem.on('connection_changed', ({ connected }: any) => {
      this.updateConnectionStatus(connected);
      if (connected) {
        this.refreshRoomList();
      }
    });
    this.eventListeners.push(unsubConnection);

    // Room events
    const unsubRoomJoined = this.multiplayerSystem.on('room_joined', ({ room }: any) => {
      this.showCurrentRoom(room);
    });
    this.eventListeners.push(unsubRoomJoined);

    const unsubRoomLeft = this.multiplayerSystem.on('room_left', () => {
      this.showWelcome();
      this.refreshRoomList();
    });
    this.eventListeners.push(unsubRoomLeft);

    const unsubPlayerJoined = this.multiplayerSystem.on('player_joined', ({ room }: any) => {
      if (this.multiplayerSystem.getCurrentRoom()) {
        this.showCurrentRoom(room);
      }
    });
    this.eventListeners.push(unsubPlayerJoined);

    const unsubPlayerLeft = this.multiplayerSystem.on('player_left', ({ room }: any) => {
      if (this.multiplayerSystem.getCurrentRoom()) {
        this.showCurrentRoom(room);
      }
    });
    this.eventListeners.push(unsubPlayerLeft);

    const unsubGameStarted = this.multiplayerSystem.on('game_started', () => {
      this.hide();
    });
    this.eventListeners.push(unsubGameStarted);
  }

  private setupButtonHandlers(element: HTMLElement): void {
    // Close button
    const closeBtn = element.querySelector('.close-btn');
    console.log('Setting up close button:', closeBtn);
    if (closeBtn) {
      closeBtn.addEventListener('click', () => {
        console.log('Close button clicked');
        this.hide();
      });
    } else {
      console.error('Close button not found!');
    }

    // Refresh rooms button
    element.querySelector('.refresh-rooms-btn')?.addEventListener('click', () => {
      this.refreshRoomList();
    });

    // Create room button
    element.querySelector('.create-room-btn')?.addEventListener('click', () => {
      this.showCreateRoomModal();
    });

    // Create room modal buttons
    element.querySelector('.confirm-create-btn')?.addEventListener('click', () => {
      this.createRoom();
    });

    element.querySelector('.cancel-create-btn')?.addEventListener('click', () => {
      this.hideCreateRoomModal();
    });

    // Room list click handler
    element.querySelector('.room-list')?.addEventListener('click', (e) => {
      const roomItem = (e.target as HTMLElement).closest('.room-item');
      if (roomItem) {
        const roomId = roomItem.getAttribute('data-room-id');
        if (roomId) {
          this.joinRoom(roomId);
        }
      }
    });

    // Dynamic button handlers will be set up when room content changes
  }

  private setupDynamicHandlers(): void {
    // Ready button
    this.element.querySelector('.ready-btn')?.addEventListener('click', () => {
      const currentPlayer = this.multiplayerSystem.getCurrentPlayer();
      if (currentPlayer) {
        this.multiplayerSystem.setReady(!currentPlayer.isReady);
      }
    });

    // Start game button
    this.element.querySelector('.start-game-btn')?.addEventListener('click', () => {
      const currentRoom = this.multiplayerSystem.getCurrentRoom();
      if (currentRoom) {
        this.multiplayerSystem.startGame();
      }
    });

    // Leave room button
    this.element.querySelector('.leave-room-btn')?.addEventListener('click', () => {
      this.multiplayerSystem.leaveRoom();
    });
  }

  private async refreshRoomList(): Promise<void> {
    const roomListElement = this.element.querySelector('.room-list');
    if (!roomListElement) return;

    try {
      roomListElement.innerHTML = '<div style="padding: 20px; text-align: center; color: #64748b;">Loading...</div>';
      
      const rooms = await this.multiplayerSystem.refreshRoomList();
      
      if (rooms.length === 0) {
        roomListElement.innerHTML = `
          <div style="
            padding: 40px 20px;
            text-align: center;
            color: #64748b;
            font-style: italic;
          ">
            No rooms available.<br>
            Create one to get started!
          </div>
        `;
      } else {
        roomListElement.innerHTML = rooms.map(room => this.getRoomHTML(room)).join('');
      }
    } catch (error) {
      roomListElement.innerHTML = `
        <div style="
          padding: 20px;
          text-align: center;
          color: #ef4444;
        ">
          Failed to load rooms
        </div>
      `;
    }
  }

  private showCreateRoomModal(): void {
    const modal = this.element.querySelector('.create-room-modal') as HTMLElement;
    if (modal) {
      modal.style.display = 'block';
      // Focus the room name input
      const nameInput = modal.querySelector('.room-name-input') as HTMLInputElement;
      if (nameInput) {
        nameInput.focus();
      }
    }
  }

  private hideCreateRoomModal(): void {
    const modal = this.element.querySelector('.create-room-modal') as HTMLElement;
    if (modal) {
      modal.style.display = 'none';
      // Clear inputs
      const nameInput = modal.querySelector('.room-name-input') as HTMLInputElement;
      if (nameInput) nameInput.value = '';
    }
  }

  private async createRoom(): Promise<void> {
    const modal = this.element.querySelector('.create-room-modal') as HTMLElement;
    const nameInput = modal.querySelector('.room-name-input') as HTMLInputElement;
    const privateCheckbox = modal.querySelector('.private-room-checkbox') as HTMLInputElement;

    if (!nameInput.value.trim()) {
      alert('Please enter a room name');
      return;
    }

    const settings: Partial<GameRoomSettings> = {
      maxTurns: 100,
      startingCash: 1000000,
      aiDifficulty: 1,
      enabledFeatures: ['trading', 'shipping', 'markets'],
      privateRoom: privateCheckbox.checked
    };

    // Check connection state first
    const multiplayerState = this.multiplayerSystem.getMultiplayerState();
    if (!multiplayerState.isConnected) {
      alert('Not connected to multiplayer server. Please wait and try again.');
      return;
    }

    // Show loading state
    const createBtn = this.element.querySelector('.create-room-submit-btn') as HTMLButtonElement;
    if (createBtn) {
      createBtn.disabled = true;
      createBtn.textContent = 'Creating room...';
    }

    try {
      const room = await this.multiplayerSystem.createRoom(nameInput.value.trim(), settings);
      if (room) {
        this.hideCreateRoomModal();
        this.showCurrentRoom(room);
        // Auto-close the lobby after successful room creation
        setTimeout(() => {
          this.hide();
        }, 1000);
      }
    } catch (error) {
      alert('Failed to create room. Please try again.');
    } finally {
      // Reset button state
      if (createBtn) {
        createBtn.disabled = false;
        createBtn.textContent = 'Create Room';
      }
    }
  }

  private async joinRoom(roomId: string): Promise<void> {
    try {
      const room = await this.multiplayerSystem.joinRoom(roomId);
      if (room) {
        this.showCurrentRoom(room);
      }
    } catch (error) {
      alert('Failed to join room. It may be full or no longer available.');
    }
  }

  private showCurrentRoom(room: GameRoom): void {
    const roomContent = this.element.querySelector('.room-content');
    const currentPlayer = this.multiplayerSystem.getCurrentPlayer();
    
    if (roomContent && currentPlayer) {
      roomContent.innerHTML = this.getCurrentRoomHTML(room, currentPlayer);
      this.setupDynamicHandlers();
    }
  }

  private showWelcome(): void {
    const roomContent = this.element.querySelector('.room-content');
    if (roomContent) {
      roomContent.innerHTML = this.getWelcomeHTML();
    }
  }

  private updateConnectionStatus(connected: boolean): void {
    const statusIndicator = this.element.querySelector('.status-indicator') as HTMLElement;
    const statusText = this.element.querySelector('.connection-status span') as HTMLElement;
    
    if (statusIndicator && statusText) {
      if (connected) {
        statusIndicator.style.background = '#10b981';
        statusText.textContent = 'Connected';
      } else {
        statusIndicator.style.background = '#ef4444';
        statusText.textContent = 'Disconnected';
      }
    }
  }

  public show(): void {
    if (!this.isVisible) {
      this.element.style.display = 'flex';
      this.isVisible = true;
      
      // Initialize with current connection state
      this.updateConnectionStatus(this.multiplayerSystem.getMultiplayerState().isConnected);
      
      // Show current room if in one, otherwise show welcome
      const currentRoom = this.multiplayerSystem.getCurrentRoom();
      if (currentRoom) {
        this.showCurrentRoom(currentRoom);
      } else {
        this.showWelcome();
        this.refreshRoomList();
      }

      // Start refresh interval
      this.refreshInterval = window.setInterval(() => {
        if (!this.multiplayerSystem.isInRoom()) {
          this.refreshRoomList();
        }
      }, 10000); // Refresh every 10 seconds
    }
  }

  public hide(): void {
    if (this.isVisible) {
      this.element.style.display = 'none';
      this.isVisible = false;
      
      // Clear refresh interval
      if (this.refreshInterval) {
        clearInterval(this.refreshInterval);
        this.refreshInterval = null;
      }
      
      // Call the hide callback if set
      if (this.onHideCallback) {
        this.onHideCallback();
      }
    }
  }

  public isShown(): boolean {
    return this.isVisible;
  }
  
  public setOnHideCallback(callback: () => void): void {
    this.onHideCallback = callback;
  }

  public destroy(): void {
    // Clean up event listeners
    this.eventListeners.forEach(unsubscribe => unsubscribe());
    this.eventListeners = [];

    // Clear intervals
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }

    // Remove from DOM
    if (this.element.parentNode) {
      this.element.parentNode.removeChild(this.element);
    }
  }
}