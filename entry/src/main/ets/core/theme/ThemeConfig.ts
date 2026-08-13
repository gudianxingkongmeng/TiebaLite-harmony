export enum DarkMode {
  FOLLOW_SYSTEM = 0,
  LIGHT = 1,
  DARK = 2,
  AMOLED = 3
}

export class ThemeConfig {
  themeIndex: number = 0;
  darkMode: DarkMode = DarkMode.FOLLOW_SYSTEM;
  isAmoled: boolean = false;
  useDynamicColor: boolean = false;
  transparentBackground: boolean = false;
  reduceEffects: boolean = false;
  hideOnScroll: boolean = true;
  fontScale: number = 1.06;
  useSystemFont: boolean = true;
  customFontIndex: number = 0;
  customColor: string = '';
  customVariant: string = 'fidelity';
}
