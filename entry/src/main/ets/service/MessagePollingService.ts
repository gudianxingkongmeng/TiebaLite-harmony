import notification from '@ohos.notification';
import { Dict } from '../core/types/Dict';
import HomeRepository from '../core/repository/HomeRepository';
import AccountManager from '../core/auth/AccountManager';
import PreferencesManager from '../core/storage/PreferencesManager';

export default class MessagePollingService {
  private static instance: MessagePollingService;
  private timer: number | null = null;
  private lastUnreadCount: number = -1;

  static getInstance(): MessagePollingService {
    if (!MessagePollingService.instance) {
      MessagePollingService.instance = new MessagePollingService();
    }
    return MessagePollingService.instance;
  }

  startPolling(intervalMs: number = 60000): void {
    if (this.timer) return;
    this.poll();
    this.timer = setInterval(() => this.poll(), intervalMs);
  }

  stopPolling(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  private async poll(): Promise<void> {
    if (!AccountManager.getInstance().isLoggedIn()) return;
    try {
      const data: Dict = await HomeRepository.getInstance().fetchMessageCount();
      const msg: Dict = (data?.message as Dict) || (data?.data as Dict)?.message as Dict || {};
      const total = Number(msg.reply || 0) + Number(msg.at || 0) + Number(msg.agree || 0);

      if (this.lastUnreadCount >= 0 && total > this.lastUnreadCount) {
        const newCount = total - this.lastUnreadCount;
        await this.showNotification(newCount);
      }
      this.lastUnreadCount = total;
    } catch (e) {}
  }

  private async showNotification(count: number): Promise<void> {
    try {
      await notification.publish({
        id: 1002,
        content: {
          contentType: notification.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'Tieba Messages',
            text: `您有 ${count} 条新消息`
          }
        }
      });
    } catch (e) {}
  }

  getUnreadCount(): number {
    return this.lastUnreadCount > 0 ? this.lastUnreadCount : 0;
  }
}
