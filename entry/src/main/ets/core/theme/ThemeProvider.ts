import { ThemeConfig, DarkMode } from './ThemeConfig';
import { BUILTIN_THEMES, ThemeColors } from './ThemeColors';
import { generateVariantScheme, ColorTriple } from './ThemeVariant';
import PreferencesManager from '../storage/PreferencesManager';

export default class ThemeProvider {
  private static instance: ThemeProvider;
  private config: ThemeConfig = new ThemeConfig();
  private observers: ((config: ThemeConfig) => void)[] = [];
  private systemDark: boolean = false;

  private constructor() {}

  static getInstance(): ThemeProvider {
    if (!ThemeProvider.instance) {
      ThemeProvider.instance = new ThemeProvider();
    }
    return ThemeProvider.instance;
  }

  async init(): Promise<void> {
    const prefs = PreferencesManager.getInstance();
    this.config.themeIndex = await prefs.getInt('theme', 0);
    this.config.darkMode = await prefs.getInt('dark_mode', DarkMode.FOLLOW_SYSTEM) as DarkMode;
    this.config.isAmoled = await prefs.getBoolean('dark_amoled', false);
    this.config.useDynamicColor = await prefs.getBoolean('use_dynamic_color', false);
    let refreshStyle = await prefs.getInt('ui_refresh_style', -1);
    if (refreshStyle < 0) {
      refreshStyle = (await prefs.getBoolean('ui_reduce_effect', false)) ? 1 : 0;
      await prefs.putInt('ui_refresh_style', refreshStyle);
    }
    this.config.refreshStyle = refreshStyle;
    this.config.reduceEffects = false;
    this.config.hideOnScroll = await prefs.getBoolean('ui_hide_on_scroll', true);
    this.config.fontScale = await prefs.getFloat('fontScale', 1.06);
    if (this.config.fontScale === 1.0 || this.config.fontScale === 1.12) {
      this.config.fontScale = 1.06;
      await prefs.putFloat('fontScale', 1.06);
    }
    this.config.transparentBackground = await prefs.getBoolean('transparent_background', false);
    this.config.useSystemFont = await prefs.getBoolean('use_system_font', true);
    this.config.customFontIndex = await prefs.getInt('custom_font', 0);
    this.config.customColor = await prefs.getString('custom_color', '');
    this.config.customVariant = await prefs.getString('custom_variant', 'fidelity');
    this.syncToAppStorage();
  }

  getConfig(): ThemeConfig {
    return this.config;
  }

  getPrimaryColor(isDark: boolean): string {
    return this.getScheme(isDark).primary;
  }

  getSecondaryColor(isDark: boolean): string {
    return this.getScheme(isDark).secondary;
  }

  getTertiaryColor(isDark: boolean): string {
    return this.getScheme(isDark).tertiary;
  }

  getScheme(isDark: boolean): ColorTriple {
    if (this.config.customColor.length > 0) {
      return generateVariantScheme(this.config.customColor, this.config.customVariant, isDark);
    }
    if (this.config.useDynamicColor) {
      return {
        primary: isDark ? ThemeColors.TIEBA_BLUE.dark : ThemeColors.TIEBA_BLUE.light,
        secondary: isDark ? ThemeColors.BLUE_VIOLET.dark : ThemeColors.BLUE_VIOLET.light,
        tertiary: isDark ? ThemeColors.JADE_GREEN.dark : ThemeColors.JADE_GREEN.light
      };
    }
    const theme = BUILTIN_THEMES[this.config.themeIndex];
    return {
      primary: isDark ? theme.primaryDark : theme.primaryLight,
      secondary: isDark ? theme.secondaryDark : theme.secondaryLight,
      tertiary: isDark ? theme.tertiaryDark : theme.tertiaryLight
    };
  }

  isDarkTheme(): boolean {
    if (this.config.themeIndex === 5) return false;
    if (this.config.themeIndex === 6) return true;
    if (this.config.darkMode === DarkMode.LIGHT) return false;
    if (this.config.darkMode === DarkMode.DARK) return true;
    if (this.config.darkMode === DarkMode.AMOLED) return true;
    return this.systemDark;
  }

  setSystemDark(isDark: boolean): void {
    this.systemDark = isDark;
    if (this.config.darkMode === DarkMode.FOLLOW_SYSTEM) {
      this.syncToAppStorage();
      this.notify();
    }
  }

  async setDarkMode(mode: DarkMode): Promise<void> {
    this.config.darkMode = mode;
    await PreferencesManager.getInstance().putInt('dark_mode', mode);
    this.syncToAppStorage();
    this.notify();
  }

  async setAmoled(v: boolean): Promise<void> {
    this.config.isAmoled = v;
    await PreferencesManager.getInstance().putBoolean('dark_amoled', v);
    this.syncToAppStorage();
    this.notify();
  }

  onChange(observer: (config: ThemeConfig) => void): void {
    this.observers.push(observer);
  }

  private notify(): void {
    for (const obs of this.observers) {
      obs(this.config);
    }
  }

  getFontFamily(): string {
    if (this.config.useSystemFont) return '';
    const FONT_FAMILIES: string[] = ['', '', 'serif', 'sans-serif', 'monospace', 'cursive'];
    const idx = this.config.customFontIndex;
    return idx >= 0 && idx < FONT_FAMILIES.length ? FONT_FAMILIES[idx] : '';
  }

  async setFontFamily(useSystem: boolean, fontIndex: number): Promise<void> {
    this.config.useSystemFont = useSystem;
    this.config.customFontIndex = fontIndex;
    const prefs = PreferencesManager.getInstance();
    await prefs.putBoolean('use_system_font', useSystem);
    await prefs.putInt('custom_font', fontIndex);
    AppStorage.SetOrCreate('appFontFamily', this.getFontFamily());
    this.notify();
  }

  syncToAppStorage(): void {
    const isDark = this.isDarkTheme();
    const scheme = this.getScheme(isDark);
    AppStorage.SetOrCreate('themeIndex', this.config.themeIndex);
    AppStorage.SetOrCreate('isDarkTheme', isDark);
    AppStorage.SetOrCreate('primaryColor', scheme.primary);
    AppStorage.SetOrCreate('secondaryColor', scheme.secondary);
    AppStorage.SetOrCreate('tertiaryColor', scheme.tertiary);
    AppStorage.SetOrCreate('fontScale', this.config.fontScale);
    AppStorage.SetOrCreate('appFontFamily', this.getFontFamily());
    AppStorage.SetOrCreate('navStyle', 0);
    AppStorage.SetOrCreate('showNavLabels', true);
    const isAmoled = this.config.themeIndex === 6 ? true : this.config.isAmoled;
    AppStorage.SetOrCreate('isAmoled', isAmoled);
    AppStorage.SetOrCreate('darkMode', this.config.darkMode);
    AppStorage.SetOrCreate('reduceEffects', this.config.reduceEffects);
    AppStorage.SetOrCreate('refreshStyle', this.config.refreshStyle);
    AppStorage.SetOrCreate('hideOnScroll', this.config.hideOnScroll);
    AppStorage.SetOrCreate('customColor', this.config.customColor);
    AppStorage.SetOrCreate('customVariant', this.config.customVariant);
  }

  async setThemeIndex(idx: number): Promise<void> {
    this.config.themeIndex = idx;
    await PreferencesManager.getInstance().putInt('theme', idx);
    this.syncToAppStorage();
    this.notify();
  }

  async setFontScale(scale: number): Promise<void> {
    this.config.fontScale = scale;
    await PreferencesManager.getInstance().putFloat('fontScale', scale);
    AppStorage.SetOrCreate('fontScale', scale);
    this.notify();
  }

  async setRefreshStyle(v: number): Promise<void> {
    this.config.refreshStyle = v;
    this.config.reduceEffects = false;
    await PreferencesManager.getInstance().putInt('ui_refresh_style', v);
    AppStorage.SetOrCreate('refreshStyle', v);
    AppStorage.SetOrCreate('reduceEffects', this.config.reduceEffects);
    this.notify();
  }

  async setCustomColor(color: string): Promise<void> {
    this.config.customColor = color;
    await PreferencesManager.getInstance().putString('custom_color', color);
    this.syncToAppStorage();
    this.notify();
  }

  async setCustomVariant(variant: string): Promise<void> {
    this.config.customVariant = variant;
    await PreferencesManager.getInstance().putString('custom_variant', variant);
    this.syncToAppStorage();
    this.notify();
  }
}
