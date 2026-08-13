import { motion } from '@kit.MultimodalAwarenessKit';
import display from '@ohos.display';

export class GripDetector {
  private static nativeAvailable: boolean = false;
  private static winWidth: number = 0;
  private static registered: boolean = false;

  static init(): void {
    if (this.registered) return;
    this.registered = true;
    try {
      motion.on('holdingHandChanged', (data: motion.HoldingHandStatus) => {
        GripDetector.nativeAvailable = true;
        let side: number = 0;
        if (data === motion.HoldingHandStatus.LEFT_HAND_HELD) {
          side = -1;
        } else if (data === motion.HoldingHandStatus.RIGHT_HAND_HELD || data === motion.HoldingHandStatus.BOTH_HANDS_HELD) {
          side = 1;
        }
        AppStorage.SetOrCreate<number>('gripSide', side);
      });
      console.info('TiebaLite: GripDetector native monitoring registered');
    } catch (e) {
      GripDetector.nativeAvailable = false;
      console.warn('TiebaLite: GripDetector native API unavailable, fallback to touch detection: ' + JSON.stringify(e));
    }
  }

  static isNativeAvailable(): boolean {
    return this.nativeAvailable;
  }

  static isEnabled(): boolean {
    return AppStorage.Get<boolean>('gripEnabled') !== false;
  }

  static touchSide(touches: Array<{ x: number }>): number {
    if (!touches) return 0;
    const w = this.getWinWidth();
    let left = false;
    let right = false;
    for (let i = 0; i < touches.length; i++) {
      const x = touches[i].x;
      if (x < w * 0.15) {
        left = true;
      } else if (x > w * 0.85) {
        right = true;
      }
    }
    if (left && right) return 1;
    if (left) return -1;
    if (right) return 1;
    return 0;
  }

  private static getWinWidth(): number {
    if (this.winWidth <= 0) {
      try {
        const info = display.getDefaultDisplaySync();
        this.winWidth = info.width / info.densityPixels;
      } catch (e) {
        this.winWidth = 360;
      }
    }
    return this.winWidth;
  }
}
