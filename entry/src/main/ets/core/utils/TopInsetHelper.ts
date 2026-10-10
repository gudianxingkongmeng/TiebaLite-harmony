import window from '@ohos.window';
import common from '@ohos.app.ability.common';
import display from '@ohos.display';

export class TopInsetHelper {
  static async getBottom(context: common.UIAbilityContext): Promise<number> {
    try {
      const win = await window.getLastWindow(context);
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      if (avoidArea.bottomRect.height > 0) {
        const density = display.getDefaultDisplaySync().densityPixels;
        return Math.max(0, Math.round(avoidArea.bottomRect.height / density));
      }
    } catch (e) {
      console.warn('TiebaLite: TopInsetHelper getBottom failed ' + JSON.stringify(e));
    }
    // 系统返回 0（手势导航条隐藏时），按屏幕高度经验值兜底：手势条区域约 8vp
    try {
      const d = display.getDefaultDisplaySync();
      if (d && d.height > 0) {
        const density = d.densityPixels;
        const screenH = d.height / density;
        return Math.max(0, Math.round(screenH * 0.03));
      }
    } catch (e) {
    }
    return 8;
  }

  static async get(context: common.UIAbilityContext): Promise<number> {
    try {
      const win = await window.getLastWindow(context);
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      if (avoidArea.topRect.height > 0) {
        const density = display.getDefaultDisplaySync().densityPixels;
        return Math.max(20, Math.round(avoidArea.topRect.height / density));
      }
    } catch (e) {
      console.warn('TiebaLite: TopInsetHelper get failed ' + JSON.stringify(e));
    }
    return 24;
  }
}
