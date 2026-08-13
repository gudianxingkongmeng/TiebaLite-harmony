import router from '@ohos.router';
import { VideoPreviewHelper } from './VideoPreviewHelper';

let isBackNavigation = false;

export class NavigationHelper {
  static get isBack(): boolean {
    return isBackNavigation;
  }

  static isFadeTransition(): boolean {
    return (AppStorage.Get<number>('pageTransitionStyle') ?? 0) === 1;
  }

  static navigate(url: string, params?: Record<string, Object>): void {
    isBackNavigation = false;
    VideoPreviewHelper.clearActive();
    router.pushUrl({ url, params });
  }

  static back(): void {
    isBackNavigation = true;
    VideoPreviewHelper.clearActive();
    router.back();
  }

  static markBack(): void {
    isBackNavigation = true;
  }
}
