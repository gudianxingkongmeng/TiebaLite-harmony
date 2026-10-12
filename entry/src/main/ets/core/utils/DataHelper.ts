import { generateBackgroundScheme } from '../theme/ThemeVariant';

export function buildPortraitUrl(portrait: string | undefined | null): string {
  if (!portrait) return '';
  const p = String(portrait);
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  const q = p.indexOf('?');
  const path = q >= 0 ? p.substring(0, q) : p;
  return 'http://tb.himg.baidu.com/sys/portraitn/item/' + path;
}

export function getField(obj: Record<string, Object> | undefined | null, ...names: string[]): Object | undefined {
  if (!obj) return undefined;
  for (const name of names) {
    const v = obj[name];
    if (v !== undefined && v !== null) return v;
  }
  return undefined;
}

function isPrimitive(v: Object): boolean {
  return typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean';
}

function extractStr(v: Object): string {
  if (typeof v === 'string') return v;
  if (typeof v === 'number') return String(v);
  if (typeof v === 'boolean') return String(v);
  return '';
}

export function getStr(obj: Record<string, Object> | undefined | null, ...names: string[]): string {
  if (!obj) return '';
  for (const name of names) {
    const v = obj[name];
    if (v !== undefined && v !== null) {
      const s = extractStr(v);
      if (s) return s;
    }
  }
  return '';
}

export function getStrObj(obj: Record<string, Object> | undefined | null, ...names: string[]): string {
  if (!obj) return '';
  for (const name of names) {
    const v = obj[name];
    if (v !== undefined && v !== null) {
      if (typeof v === 'string') return v;
      if (typeof v === 'object') {
        const s = extractStr(v as Record<string, Object>);
        if (s) return s;
      }
      const s = extractStr(v);
      if (s) return s;
    }
  }
  return '';
}

export function getNum(obj: Record<string, Object> | undefined | null, ...names: string[]): number {
  if (!obj) return 0;
  for (const name of names) {
    const v = obj[name];
    if (v !== undefined && v !== null) {
      if (typeof v === 'number') return v;
      if (typeof v === 'string') {
        const n = Number(v);
        if (!isNaN(n)) return n;
      }
    }
  }
  return 0;
}

export function blendWithWhite(hexColor: string, ratio: number): string {
  const r = parseInt(hexColor.substring(1, 3), 16);
  const g = parseInt(hexColor.substring(3, 5), 16);
  const b = parseInt(hexColor.substring(5, 7), 16);
  const wr = Math.round(r * ratio + 255 * (1 - ratio));
  const wg = Math.round(g * ratio + 255 * (1 - ratio));
  const wb = Math.round(b * ratio + 255 * (1 - ratio));
  return '#' + wr.toString(16).padStart(2, '0') + wg.toString(16).padStart(2, '0') + wb.toString(16).padStart(2, '0');
}

export function darkenColor(hexColor: string, factor: number): string {
  const r = parseInt(hexColor.substring(1, 3), 16);
  const g = parseInt(hexColor.substring(3, 5), 16);
  const b = parseInt(hexColor.substring(5, 7), 16);
  const dr = Math.round(r * (1 - factor));
  const dg = Math.round(g * (1 - factor));
  const db = Math.round(b * (1 - factor));
  return '#' + dr.toString(16).padStart(2, '0') + dg.toString(16).padStart(2, '0') + db.toString(16).padStart(2, '0');
}

export function textAccent(primaryColor: string, isDark: boolean): string {
  return primaryColor;
}

const PRIMARY_CONTAINERS: Record<number, { light: string; dark: string }> = {
  0: { light: '#D9E2FF', dark: '#2F4578' },
  1: { light: '#EFDBFF', dark: '#553B71' },
  2: { light: '#A6F2D1', dark: '#00513B' },
  3: { light: '#FFD9E2', dark: '#703349' },
  4: { light: '#FFDBCD', dark: '#71361A' },
  5: { light: '#D9E2FF', dark: '#2F4578' },
  6: { light: '#D9E2FF', dark: '#2F4578' }
};

export function primaryContainer(isDark: boolean): string {
  const idx = getThemeIdx();
  const c = PRIMARY_CONTAINERS[idx];
  if (c) return isDark ? c.dark : c.light;
  const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
  return isDark ? blendWithBg(primary, 0.2, true) : blendWithWhite(primary, 0.16);
}

export function onPrimaryContainer(isDark: boolean): string {
  const idx = getThemeIdx();
  const c = PRIMARY_CONTAINERS[idx];
  if (c) return isDark ? c.light : c.dark;
  const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
  return isDark ? blendWithWhite(primary, 0.82) : primary;
}

export const KEYBOARD_IME_EXTRA_VP: number = 0;

export function blendWithBg(hexColor: string, ratio: number, isDark: boolean, darkBase: string = '#121212'): string {
  if (!isDark) {
    if (getThemeIdx() === 5) return '#FFFFFF';
    return blendWithWhite(hexColor, ratio);
  }
  const isAmoled = AppStorage.Get<boolean>('isAmoled') ?? false;
  if (isAmoled && (darkBase === '#121212' || darkBase === '#1E1E1E')) {
    darkBase = '#000000';
  }
  const r = parseInt(hexColor.substring(1, 3), 16);
  const g = parseInt(hexColor.substring(3, 5), 16);
  const b = parseInt(hexColor.substring(5, 7), 16);
  const dr = parseInt(darkBase.substring(1, 3), 16);
  const dg = parseInt(darkBase.substring(3, 5), 16);
  const db = parseInt(darkBase.substring(5, 7), 16);
  const br = Math.round(r * ratio + dr * (1 - ratio));
  const bgc = Math.round(g * ratio + dg * (1 - ratio));
  const bb = Math.round(b * ratio + db * (1 - ratio));
  return '#' + br.toString(16).padStart(2, '0') + bgc.toString(16).padStart(2, '0') + bb.toString(16).padStart(2, '0');
}

export function isDarkTheme(): boolean {
  return AppStorage.Get<boolean>('isDarkTheme') ?? false;
}

function getThemeIdx(): number {
  return AppStorage.Get<number>('themeIndex') ?? -1;
}

function isInkDark(): boolean {
  return AppStorage.Get<number>('themeIndex') === 6;
}

const THEME_MATERIAL: Record<number, {
  light: { bg: string; surface: string; surfaceVariant: string; textPrimary: string; textSecondary: string; outlineVariant: string; outline: string };
  dark: { bg: string; surface: string; surfaceVariant: string; textPrimary: string; textSecondary: string; outlineVariant: string; outline: string }
}> = {
  0: { // 贴吧蓝 #4477E0
    light: { bg: '#F9F9FF', surface: '#FFFFFF', surfaceVariant: '#E2E2E9', textPrimary: '#1A1B20', textSecondary: '#44464F', outlineVariant: '#C5C6D0', outline: '#757780' },
    dark: { bg: '#111318', surface: '#1E1E1E', surfaceVariant: '#33353A', textPrimary: '#E2E2E9', textSecondary: '#C5C6D0', outlineVariant: '#44464F', outline: '#8F9099' }
  },
  1: { // 紫罗兰 #8A2BE2
    light: { bg: '#FFF7FE', surface: '#FFFFFF', surfaceVariant: '#E8E0E8', textPrimary: '#1E1A20', textSecondary: '#4A454E', outlineVariant: '#CCC4CE', outline: '#7B757E' },
    dark: { bg: '#151217', surface: '#1E1E1E', surfaceVariant: '#373339', textPrimary: '#E8E0E8', textSecondary: '#CCC4CE', outlineVariant: '#4A454E', outline: '#968E98' }
  },
  2: { // 翡翠绿 #019C74
    light: { bg: '#F5FBF7', surface: '#FFFFFF', surfaceVariant: '#DEE4E0', textPrimary: '#171D1B', textSecondary: '#404944', outlineVariant: '#BFC9C2', outline: '#707974' },
    dark: { bg: '#0E1513', surface: '#1E1E1E', surfaceVariant: '#303634', textPrimary: '#DEE4E0', textSecondary: '#BFC9C2', outlineVariant: '#404944', outline: '#89938D' }
  },
  3: { // 樱花粉 #E986A7
    light: { bg: '#FFF8F8', surface: '#FFFFFF', surfaceVariant: '#EFDFE2', textPrimary: '#22191C', textSecondary: '#514347', outlineVariant: '#D5C2C6', outline: '#837377' },
    dark: { bg: '#191114', surface: '#1E1E1E', surfaceVariant: '#3C3235', textPrimary: '#EFDFE2', textSecondary: '#D5C2C6', outlineVariant: '#514347', outline: '#9E8C90' }
  },
  4: { // 日落橙 #FD742D
    light: { bg: '#FFF8F6', surface: '#FFFFFF', surfaceVariant: '#F1DFD8', textPrimary: '#221A16', textSecondary: '#53443D', outlineVariant: '#D8C2BA', outline: '#85736C' },
    dark: { bg: '#1A120E', surface: '#1E1E1E', surfaceVariant: '#3D332E', textPrimary: '#F1DFD8', textSecondary: '#D8C2BA', outlineVariant: '#53443D', outline: '#A08D85' }
  }
};

function getMaterial(isDark: boolean): typeof THEME_MATERIAL[0]['light'] {
  const idx = getThemeIdx();
  const theme = THEME_MATERIAL[idx];
  if (!theme) {
    return isDark
      ? { bg: '#111318', surface: '#1E1E1E', surfaceVariant: '#33353A', textPrimary: '#E2E2E9', textSecondary: '#C5C6D0', outlineVariant: '#44464F', outline: '#8F9099' }
      : { bg: '#F9F9FF', surface: '#FFFFFF', surfaceVariant: '#E2E2E9', textPrimary: '#1A1B20', textSecondary: '#44464F', outlineVariant: '#C5C6D0', outline: '#757780' };
  }
  return isDark ? theme.dark : theme.light;
}

export function pageBg(isDark: boolean): string {
  const custom = AppStorage.Get<string>('customColor') ?? '';
  if (custom.length > 0) {
    const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
    return generateBackgroundScheme(primary, isDark).bg;
  }
  const idx = getThemeIdx();
  if (idx === 5) {
    const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
    return blendWithWhite(primary, 0.03);
  }
  if (idx === 6) {
    const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
    return blendWithBg(primary, 0.06, true);
  }
  return getMaterial(isDark).bg;
}

export function cardBg(isDark: boolean): string {
  const custom = AppStorage.Get<string>('customColor') ?? '';
  if (custom.length > 0) {
    const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
    return generateBackgroundScheme(primary, isDark).surface;
  }
  const idx = getThemeIdx();
  if (idx === 5) return '#F5F5F5';
  if (idx === 6) return '#000000';
  return getMaterial(isDark).surface;
}

export function cardRadius(radius: number): number {
  return radius;
}

export function surfaceVariant(isDark: boolean): string {
  const custom = AppStorage.Get<string>('customColor') ?? '';
  if (custom.length > 0) {
    const primary = AppStorage.Get<string>('primaryColor') ?? '#4477E0';
    return generateBackgroundScheme(primary, isDark).surfaceVariant;
  }
  const idx = getThemeIdx();
  if (idx === 5) return '#E8E8E8';
  if (idx === 6) return '#111111';
  return getMaterial(isDark).surfaceVariant;
}

export function textPrimary(isDark: boolean): string {
  if (isInkDark()) return '#FFFFFF';
  return getMaterial(isDark).textPrimary;
}

export function textSecondary(isDark: boolean): string {
  if (isInkDark()) return '#CCCCCC';
  return getMaterial(isDark).textSecondary;
}

export function textTertiary(isDark: boolean): string {
  if (isInkDark()) return '#999999';
  return getMaterial(isDark).outlineVariant;
}

export function dividerColor(isDark: boolean): string {
  if (getThemeIdx() === 6) return 'rgba(255,255,255,0.08)';
  return getMaterial(isDark).outline;
}

export function shadowColor(isDark: boolean): string {
      return isDark ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.1)';
    }
    
    export function glassSurface(isDark: boolean): string {
      return isDark ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.55)';
    }
    
    export function glassBorder(isDark: boolean): string {
      return isDark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.75)';
    }
    
    export function glassShadow(isDark: boolean): string {
      return isDark ? 'rgba(0,0,0,0.45)' : 'rgba(0,0,0,0.16)';
    }
    
    export function glassBlur(): number {
      return 30;
    }
    
export function glassTintSurface(primaryColor: string, isDark: boolean, glassAlpha: number,
  density: number = 0, fade: number = 1): string {
  // 玻璃强度 0 = 完全不透明装饰，必须真的透明而不是降到 0.35 倍
  if (glassAlpha <= 0) {
    return 'transparent';
  }
      // density 用于同材质下的层级区分：操作条类传 1，底色略实一档
      const extra = Math.max(0, Math.min(1, density)) * 0.12;
      // fade 用于整条变淡（如导航条要求"底色淡一半"），保留为相对倍率
      const base = (1 + extra) * Math.max(0, Math.min(1, fade));
      const a = Math.min(1, base * glassRatio(glassAlpha));
      return withAlpha(primaryColor, a);
    }
    
export function glassTintBorder(primaryColor: string, isDark: boolean, glassAlpha: number): string {
  if (glassAlpha <= 0) {
    return 'transparent';
  }
  const base = isDark ? 0.55 : 0.6;
  return withAlpha(primaryColor, base * glassRatio(glassAlpha));
}
    
export function glassTintShadow(primaryColor: string, isDark: boolean, glassAlpha: number): string {
  // 玻璃强度 0 时不该还有投影，否则纯透明条仍会带一层灰影
  if (glassAlpha <= 0) {
    return 'transparent';
  }
  const base = isDark ? 0.42 : 0.45;
  return withAlpha(primaryColor, base * glassRatio(glassAlpha));
}
    
/**
 * 玻璃强度 0..100 → 0..1 的线性系数。
 *
 * 之前的写法是 base * (0.35 + 0.65 * x) 这种「快速起步、后段趋平」的曲线：
 * 强度 1 就已经跳到 35%，强度 100 也只能到 base，永远到不了真正的满值。
 * 用户看到的中间态不线性、最大值也不够透明/不透明，根因就在这里。
 * 现在统一线性：0 全透明，100 达到该 helper 的设计上���，中间按比例过渡。
 */
export function glassRatio(glassAlpha: number): number {
  if (glassAlpha <= 0) return 0;
  return Math.max(0, Math.min(1, glassAlpha / 100));
}

export function glassBlurLevel(glassAlpha: number): number {
  // 线性跟随强度，不再用 Math.max(6, ...) 抬高低区间（那会让前段失真）
  return Math.round(35 * glassRatio(glassAlpha));
}

/**
 * 顶栏/底条的 backdropBlur。
 * 直接写 glassBlurLevel(x) + 14 会在 glassAlpha=0 时仍然得到 14 的模糊，
 * 导致「玻璃强度设为 0」并不是真的纯透明。这里统一兜底为 0。
 */
export function glassBackdropBlur(glassAlpha: number, extra: number = 0): number {
  if (glassAlpha <= 0) return 0;
  return glassBlurLevel(glassAlpha) + extra;
}

    /**
     * 液态玻璃增强参数：在 backdropBlur 之上叠加色彩调整，
     * 让毛玻璃往"通透的液态玻璃"观感靠拢。
     * - saturation：提升背景色彩饱和度，产生通透感
     * - brightness：轻微提亮，模拟玻璃厚度带来的聚光
     * - color：叠加一层极淡的白色高光
     * 重度（emphasis）用于让展开的操作条比主按钮更"重"。
     */
export function liquidGlassEffect(emphasis: number = 0, glassAlpha: number = 25): BackgroundEffectOptions {
  // 玻璃强度为 0 时必须完全中性：否则这层白色 tint 会叠加在透明背景上，
  // 使「设为 0」依然看起来有一层玻璃，而不是纯透明。
  if (glassAlpha <= 0) {
    return { radius: 0, saturation: 1, brightness: 1 };
  }
  const e = Math.max(0, Math.min(1, emphasis));
  const ratio = glassRatio(glassAlpha);
  // color 必须是字符串形式的 RGBA，0x0AFFFFFF 是 alpha 0x0A 的白色高光层
  // 叠加后得到的通透感
  const tintAlpha = Math.round((10 + 8 * e) * ratio);
  return {
    radius: glassBlurLevel(glassAlpha) + Math.round(8 * e * ratio),
    saturation: 1 + 0.35 * e * ratio,
    brightness: 1 + 0.06 * e * ratio,
    color: '#' + tintAlpha.toString(16).padStart(2, '0') + 'FFFFFF'
  };
}

    /** 液态玻璃的边缘高光描边颜色：顶部亮、底部暗，模拟透镜受光。 */
export function liquidGlassEdge(isDark: boolean, emphasis: number = 0, glassAlpha: number = -1): string {
  // glassAlpha 传入时，0 表示关闭玻璃，描边也应一并消失
  if (glassAlpha === 0) {
    return 'transparent';
  }
  const e = Math.max(0, Math.min(1, emphasis));
      // 边缘高光：深色背景下用更亮的白，浅色背景下稍暗一点才看得见
      const rgb = isDark ? '#FFFFFF' : '#F2F6FF';
      const alpha = isDark ? 0.4 + 0.16 * e : 0.55 + 0.2 * e;
      return withAlpha(rgb, alpha);
    }

    /**
     * 顶栏玻璃统一入口：所有页面顶栏共用，保证视觉一致。
     * 底色取「页面背景色」而非主题色——顶栏与下方内容同色，玻璃只做模糊与通透，
     * 不会出现顶栏偏蓝、内容偏灰的割裂感。
     * headerAlpha=0 时返回透明，保持"关闭玻璃"的既有行为。
     */
    export function glassTopBarSurface(pageBgColor: string, isDark: boolean, glassAlpha: number): string {
      if (glassAlpha <= 0) {
        return 'transparent';
      }
      // 底色用页面背景色（和下方主贴同源），不透明度对强度线性：
      // 0 全透明、100 完全不透明、中间按比例过渡。
      // 颜色一致靠的是不做 hue shift（见 glassTopBarEffect），不是靠调不透明度。
      return withAlpha(pageBgColor, glassRatio(glassAlpha));
    }

    /**
     * 顶栏的 backgroundEffect 参数。
     * 这里刻意不做提亮/增饱和：顶栏底色必须和下方主贴一致，
     * saturation/brightness 一改色相就会和主贴对不上。
     * 只保留模糊半径与一层极淡的高光。
     */
    export function glassTopBarEffect(glassAlpha: number): BackgroundEffectOptions {
      if (glassAlpha <= 0) {
        return { radius: 0, saturation: 1, brightness: 1 };
      }
      return {
        radius: glassBlurLevel(glassAlpha) + 6,
        saturation: 1,
        brightness: 1,
        color: '#05FFFFFF'
      };
    }
    
export function withAlpha(color: string, alpha: number): string {
  if (color.startsWith('#')) {
    const h = color.substring(1);
    if (h.length === 3) {
      const r = parseInt(h.charAt(0) + h.charAt(0), 16);
      const g = parseInt(h.charAt(1) + h.charAt(1), 16);
      const b = parseInt(h.charAt(2) + h.charAt(2), 16);
      return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
    }
    if (h.length >= 6) {
      const r = parseInt(h.substring(0, 2), 16);
      const g = parseInt(h.substring(2, 4), 16);
      const b = parseInt(h.substring(4, 6), 16);
      return 'rgba(' + r + ',' + g + ',' + b + ',' + alpha + ')';
    }
  }
  return color;
}
