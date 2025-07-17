import { ProgressionSystem } from '@/systems/ProgressionSystem';
import { Achievement } from '@/types';

export class ProgressionUI {
  private progressionSystem: ProgressionSystem;
  private container: HTMLElement;
  private levelDisplay: HTMLElement | null = null;
  private xpBar: HTMLElement | null = null;
  private achievementPanel: HTMLElement | null = null;
  private notificationQueue: Array<{ type: string; message: string; icon?: string }> = [];
  private isProcessingNotification = false;

  constructor(progressionSystem: ProgressionSystem) {
    this.progressionSystem = progressionSystem;
    this.container = document.getElementById('ui-overlay')!;
    this.initialize();
  }

  private initialize(): void {
    this.createLevelDisplay();
    this.createAchievementPanel();
    this.setupEventListeners();
    this.addStyles();
  }

  private addStyles(): void {
    const style = document.createElement('style');
    style.textContent = `
      .progression-container {
        position: absolute;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 12px;
        z-index: 100;
      }

      .level-display {
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(59, 130, 246, 0.3);
        border-radius: 12px;
        padding: 12px 24px;
        color: white;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        min-width: 300px;
      }

      .level-info {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 8px;
      }

      .level-text {
        font-size: 16px;
        font-weight: bold;
        color: #3b82f6;
      }

      .xp-text {
        font-size: 12px;
        color: #94a3b8;
      }

      .xp-bar-container {
        width: 100%;
        height: 8px;
        background: rgba(59, 130, 246, 0.2);
        border-radius: 4px;
        overflow: hidden;
        position: relative;
      }

      .xp-bar-fill {
        height: 100%;
        background: linear-gradient(90deg, #3b82f6, #6366f1);
        transition: width 0.5s ease-out;
        position: relative;
        overflow: hidden;
      }

      .xp-bar-fill::after {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: linear-gradient(
          90deg,
          transparent,
          rgba(255, 255, 255, 0.3),
          transparent
        );
        animation: shimmer 2s infinite;
      }

      @keyframes shimmer {
        0% { transform: translateX(-100%); }
        100% { transform: translateX(100%); }
      }

      .achievement-panel {
        position: absolute;
        top: 80px;
        right: 20px;
        width: 320px;
        max-height: 400px;
        background: rgba(15, 23, 42, 0.95);
        backdrop-filter: blur(10px);
        border: 1px solid rgba(59, 130, 246, 0.3);
        border-radius: 12px;
        padding: 20px;
        color: white;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        display: none;
        overflow-y: auto;
      }

      .achievement-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 16px;
      }

      .achievement-title {
        font-size: 18px;
        font-weight: bold;
        color: #3b82f6;
      }

      .achievement-stats {
        font-size: 12px;
        color: #94a3b8;
      }

      .achievement-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .achievement-item {
        background: rgba(30, 41, 59, 0.5);
        border: 1px solid rgba(59, 130, 246, 0.2);
        border-radius: 8px;
        padding: 12px;
        transition: all 0.2s ease;
      }

      .achievement-item:hover {
        border-color: rgba(59, 130, 246, 0.5);
        background: rgba(30, 41, 59, 0.8);
      }

      .achievement-item.unlocked {
        border-color: rgba(16, 185, 129, 0.5);
        background: rgba(16, 185, 129, 0.1);
      }

      .achievement-name {
        font-size: 14px;
        font-weight: bold;
        margin-bottom: 4px;
      }

      .achievement-description {
        font-size: 12px;
        color: #94a3b8;
        margin-bottom: 8px;
      }

      .achievement-progress {
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .achievement-progress-bar {
        flex: 1;
        height: 4px;
        background: rgba(59, 130, 246, 0.2);
        border-radius: 2px;
        overflow: hidden;
      }

      .achievement-progress-fill {
        height: 100%;
        background: #3b82f6;
        transition: width 0.3s ease;
      }

      .achievement-progress-text {
        font-size: 11px;
        color: #94a3b8;
        min-width: 50px;
        text-align: right;
      }

      .progression-notification {
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%) scale(0);
        background: linear-gradient(135deg, rgba(59, 130, 246, 0.95), rgba(99, 102, 241, 0.95));
        backdrop-filter: blur(10px);
        border: 2px solid rgba(255, 255, 255, 0.3);
        border-radius: 16px;
        padding: 24px 32px;
        color: white;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);
        text-align: center;
        z-index: 2000;
        animation: notificationPop 0.5s ease-out forwards;
      }

      @keyframes notificationPop {
        0% {
          transform: translate(-50%, -50%) scale(0);
          opacity: 0;
        }
        50% {
          transform: translate(-50%, -50%) scale(1.1);
        }
        100% {
          transform: translate(-50%, -50%) scale(1);
          opacity: 1;
        }
      }

      .notification-icon {
        font-size: 48px;
        margin-bottom: 12px;
      }

      .notification-title {
        font-size: 24px;
        font-weight: bold;
        margin-bottom: 8px;
      }

      .notification-message {
        font-size: 16px;
        opacity: 0.9;
      }

      .xp-popup {
        position: absolute;
        font-size: 18px;
        font-weight: bold;
        color: #fbbf24;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5);
        pointer-events: none;
        animation: xpFloat 2s ease-out forwards;
      }

      @keyframes xpFloat {
        0% {
          transform: translateY(0);
          opacity: 1;
        }
        100% {
          transform: translateY(-50px);
          opacity: 0;
        }
      }

      .unlock-badge {
        display: inline-block;
        background: linear-gradient(135deg, #f59e0b, #f97316);
        color: white;
        padding: 4px 12px;
        border-radius: 16px;
        font-size: 12px;
        font-weight: bold;
        margin-left: 8px;
        animation: pulse 1s ease-in-out infinite;
      }

      @keyframes pulse {
        0%, 100% { transform: scale(1); }
        50% { transform: scale(1.05); }
      }
    `;
    document.head.appendChild(style);
  }

  private createLevelDisplay(): void {
    const container = document.createElement('div');
    container.className = 'progression-container';

    const levelDisplay = document.createElement('div');
    levelDisplay.className = 'level-display';
    levelDisplay.innerHTML = `
      <div class="level-info">
        <div class="level-text">Level 1</div>
        <div class="xp-text">0 / 100 XP</div>
      </div>
      <div class="xp-bar-container">
        <div class="xp-bar-fill" style="width: 0%"></div>
      </div>
    `;

    container.appendChild(levelDisplay);
    this.container.appendChild(container);
    this.levelDisplay = levelDisplay;
    this.xpBar = levelDisplay.querySelector('.xp-bar-fill');
  }

  private createAchievementPanel(): void {
    const panel = document.createElement('div');
    panel.className = 'achievement-panel';
    panel.innerHTML = `
      <div class="achievement-header">
        <div class="achievement-title">Achievements</div>
        <button class="close-btn" style="background: none; border: none; color: #94a3b8; cursor: pointer; font-size: 18px;">&times;</button>
      </div>
      <div class="achievement-stats">0 / 0 Unlocked (0%)</div>
      <div class="achievement-list"></div>
    `;

    this.container.appendChild(panel);
    this.achievementPanel = panel;

    // Setup close button
    panel.querySelector('.close-btn')?.addEventListener('click', () => {
      this.hideAchievementPanel();
    });
  }

  private setupEventListeners(): void {
    // Listen for progression events
    window.addEventListener('progression:unlock', (event: any) => {
      this.showUnlockNotification(event.detail.unlock);
    });

    window.addEventListener('progression:achievement', (event: any) => {
      this.showAchievementNotification(event.detail.achievement);
    });

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      if (e.code === 'KeyA' && !e.ctrlKey && !e.metaKey) {
        this.toggleAchievementPanel();
      }
    });

    // Click on level display to show achievements
    this.levelDisplay?.addEventListener('click', () => {
      this.toggleAchievementPanel();
    });
  }

  public update(): void {
    this.updateLevelDisplay();
    this.updateAchievementPanel();
  }

  private updateLevelDisplay(): void {
    if (!this.levelDisplay || !this.xpBar) return;

    const progress = this.progressionSystem.getProgressToNextLevel();
    
    const levelText = this.levelDisplay.querySelector('.level-text');
    const xpText = this.levelDisplay.querySelector('.xp-text');
    
    if (levelText) {
      levelText.textContent = `Level ${progress.currentLevel}`;
    }
    
    if (xpText) {
      if (progress.currentLevel >= 50) {
        xpText.textContent = 'MAX LEVEL';
      } else {
        xpText.textContent = `${this.formatNumber(progress.currentXP)} / ${this.formatNumber(progress.requiredXP)} XP`;
      }
    }
    
    this.xpBar.style.width = `${progress.progress}%`;
  }

  private updateAchievementPanel(): void {
    if (!this.achievementPanel) return;

    const stats = this.progressionSystem.getAchievementStats();
    const statsElement = this.achievementPanel.querySelector('.achievement-stats');
    if (statsElement) {
      statsElement.textContent = `${stats.unlocked} / ${stats.total} Unlocked (${Math.round(stats.percentage)}%)`;
    }

    const listElement = this.achievementPanel.querySelector('.achievement-list');
    if (listElement && listElement.children.length === 0) {
      // Only populate if empty (to avoid constant re-rendering)
      this.populateAchievementList(listElement as HTMLElement);
    }
  }

  private populateAchievementList(container: HTMLElement): void {
    const achievements = this.progressionSystem['gameState'].player.achievements;
    
    container.innerHTML = achievements.map(achievement => `
      <div class="achievement-item ${achievement.unlocked ? 'unlocked' : ''}">
        <div class="achievement-name">
          ${achievement.name}
          ${achievement.unlocked ? '<span style="color: #10b981; margin-left: 8px;">✓</span>' : ''}
        </div>
        <div class="achievement-description">${achievement.description}</div>
        ${!achievement.unlocked ? `
          <div class="achievement-progress">
            <div class="achievement-progress-bar">
              <div class="achievement-progress-fill" style="width: ${(achievement.progress / achievement.maxProgress) * 100}%"></div>
            </div>
            <div class="achievement-progress-text">${achievement.progress} / ${achievement.maxProgress}</div>
          </div>
        ` : ''}
      </div>
    `).join('');
  }

  private toggleAchievementPanel(): void {
    if (!this.achievementPanel) return;
    
    const isVisible = this.achievementPanel.style.display !== 'none';
    if (isVisible) {
      this.hideAchievementPanel();
    } else {
      this.showAchievementPanel();
    }
  }

  private showAchievementPanel(): void {
    if (this.achievementPanel) {
      this.achievementPanel.style.display = 'block';
      this.updateAchievementPanel();
    }
  }

  private hideAchievementPanel(): void {
    if (this.achievementPanel) {
      this.achievementPanel.style.display = 'none';
    }
  }

  public showXPGain(amount: number, x: number, y: number): void {
    const popup = document.createElement('div');
    popup.className = 'xp-popup';
    popup.textContent = `+${amount} XP`;
    popup.style.left = `${x}px`;
    popup.style.top = `${y}px`;
    
    this.container.appendChild(popup);
    
    setTimeout(() => {
      popup.remove();
    }, 2000);
  }

  private showUnlockNotification(unlock: string): void {
    this.notificationQueue.push({
      type: 'unlock',
      message: this.formatUnlockName(unlock),
      icon: '🔓'
    });
    this.processNotificationQueue();
  }

  private showAchievementNotification(achievement: Achievement): void {
    this.notificationQueue.push({
      type: 'achievement',
      message: achievement.name,
      icon: '🏆'
    });
    this.processNotificationQueue();
  }

  private async processNotificationQueue(): Promise<void> {
    if (this.isProcessingNotification || this.notificationQueue.length === 0) {
      return;
    }

    this.isProcessingNotification = true;
    const notification = this.notificationQueue.shift()!;

    const notificationElement = document.createElement('div');
    notificationElement.className = 'progression-notification';
    notificationElement.innerHTML = `
      <div class="notification-icon">${notification.icon}</div>
      <div class="notification-title">
        ${notification.type === 'unlock' ? 'New Unlock!' : 'Achievement Unlocked!'}
      </div>
      <div class="notification-message">${notification.message}</div>
    `;

    this.container.appendChild(notificationElement);

    // Auto-hide after 3 seconds
    setTimeout(() => {
      notificationElement.style.animation = 'notificationPop 0.5s ease-in reverse';
      setTimeout(() => {
        notificationElement.remove();
        this.isProcessingNotification = false;
        this.processNotificationQueue();
      }, 500);
    }, 3000);
  }

  private formatUnlockName(unlock: string): string {
    return unlock
      .split('_')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  private formatNumber(num: number): string {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return Math.round(num).toString();
  }

  public showLevelUpNotification(newLevel: number, unlocks: string[]): void {
    const notification = document.createElement('div');
    notification.className = 'progression-notification';
    notification.style.background = 'linear-gradient(135deg, rgba(16, 185, 129, 0.95), rgba(5, 150, 105, 0.95))';
    notification.innerHTML = `
      <div class="notification-icon">⭐</div>
      <div class="notification-title">Level ${newLevel} Reached!</div>
      <div class="notification-message">
        ${unlocks.length > 0 ? `Unlocked: ${unlocks.map(u => this.formatUnlockName(u)).join(', ')}` : 'Keep progressing to unlock new features!'}
      </div>
    `;

    this.container.appendChild(notification);

    setTimeout(() => {
      notification.style.animation = 'notificationPop 0.5s ease-in reverse';
      setTimeout(() => {
        notification.remove();
      }, 500);
    }, 4000);
  }

  public destroy(): void {
    this.levelDisplay?.remove();
    this.achievementPanel?.remove();
    window.removeEventListener('progression:unlock', () => {});
    window.removeEventListener('progression:achievement', () => {});
  }
}