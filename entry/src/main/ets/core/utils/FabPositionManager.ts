import PreferencesManager from '../storage/PreferencesManager';

export interface FabOffset {
  dx: number;
  dy: number;
}

const PREF_PREFIX = 'fab_pos_';

export class FabPositionManager {
  static async load(fabKey: string): Promise<FabOffset> {
    try {
      const raw = await PreferencesManager.getInstance().getString(PREF_PREFIX + fabKey, '');
      if (!raw) {
        return { dx: 0, dy: 0 };
      }
      const parts = raw.split(',');
      const dx = Number(parts[0]);
      const dy = Number(parts[1]);
      if (isNaN(dx) || isNaN(dy)) {
        return { dx: 0, dy: 0 };
      }
      return { dx: dx, dy: dy };
    } catch (e) {
      return { dx: 0, dy: 0 };
    }
  }

  static async save(fabKey: string, dx: number, dy: number): Promise<void> {
    try {
      await PreferencesManager.getInstance().putString(PREF_PREFIX + fabKey, dx + ',' + dy);
    } catch (e) {
    }
  }

  static async reset(fabKey: string): Promise<void> {
    try {
      await PreferencesManager.getInstance().putString(PREF_PREFIX + fabKey, '0,0');
    } catch (e) {
    }
  }
}
