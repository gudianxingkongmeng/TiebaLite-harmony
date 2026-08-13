import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';

export default class PreferencesManager {
  private static instance: PreferencesManager;
  private preferences?: preferences.Preferences;
  private context: common.Context;

  private constructor(context: common.Context) {
    this.context = context;
  }

  static init(context: common.Context): void {
    if (!PreferencesManager.instance) {
      PreferencesManager.instance = new PreferencesManager(context);
    }
  }

  static getInstance(): PreferencesManager {
    return PreferencesManager.instance;
  }

  private async getPreferences(): Promise<preferences.Preferences> {
    if (!this.preferences) {
      this.preferences = await preferences.getPreferences(this.context, 'app_preferences');
    }
    return this.preferences;
  }

  async putString(key: string, value: string): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.put(key, value);
    await prefs.flush();
  }

  async putBoolean(key: string, value: boolean): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.put(key, value);
    await prefs.flush();
  }

  async putInt(key: string, value: number): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.put(key, value);
    await prefs.flush();
  }

  async putFloat(key: string, value: number): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.put(key, value);
    await prefs.flush();
  }

  async getString(key: string, defaultValue?: string): Promise<string> {
    const prefs = await this.getPreferences();
    const val = await prefs.get(key, defaultValue ?? '');
    return val as string;
  }

  async getBoolean(key: string, defaultValue?: boolean): Promise<boolean> {
    const prefs = await this.getPreferences();
    const val = await prefs.get(key, defaultValue ?? false);
    return val as boolean;
  }

  async getInt(key: string, defaultValue?: number): Promise<number> {
    const prefs = await this.getPreferences();
    const val = await prefs.get(key, defaultValue ?? 0);
    return val as number;
  }

  async getFloat(key: string, defaultValue?: number): Promise<number> {
    const prefs = await this.getPreferences();
    const val = await prefs.get(key, defaultValue ?? 0.0);
    return val as number;
  }

  async remove(key: string): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.delete(key);
    await prefs.flush();
  }

  async clear(): Promise<void> {
    const prefs = await this.getPreferences();
    await prefs.clear();
    await prefs.flush();
  }
}
