export interface ColorTriple {
  primary: string;
  secondary: string;
  tertiary: string;
}

export interface VariantDef {
  key: string;
  name: string;
}

export const VARIANTS: VariantDef[] = [
  { key: 'tonal_spot', name: '平静' },
  { key: 'vibrant', name: '高活力' },
  { key: 'expressive', name: '表现力' },
  { key: 'fidelity', name: '精确' },
  { key: 'rainbow', name: '缤纷' },
  { key: 'fruit_salad', name: '沙拉' },
  { key: 'neutral', name: '暗淡' },
  { key: 'monochrome', name: '单色' }
];

interface Hsl {
  h: number;
  s: number;
  l: number;
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, v));
}

function hexToHsl(hex: string): Hsl {
  const r = parseInt(hex.substring(1, 3), 16) / 255;
  const g = parseInt(hex.substring(3, 5), 16) / 255;
  const b = parseInt(hex.substring(5, 7), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  let h = 0;
  let s = 0;
  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max === r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (max === g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
  }
  return { h: h * 360, s: s * 100, l: l * 100 };
}

function hslToHex(h: number, s: number, l: number): string {
  const hh = clamp(h, 0, 360) / 360;
  const ss = clamp(s, 0, 100) / 100;
  const ll = clamp(l, 0, 100) / 100;
  if (ss === 0) {
    const v = Math.round(ll * 255);
    const vh = v.toString(16).padStart(2, '0');
    return '#' + vh + vh + vh;
  }
  const hue2rgb = (p: number, q: number, t: number): number => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  const q = ll < 0.5 ? ll * (1 + ss) : ll + ss - ll * ss;
  const p = 2 * ll - q;
  const to2 = (v: number): string => {
    const s2 = clamp(Math.round(v * 255), 0, 255).toString(16);
    return s2.length === 1 ? '0' + s2 : s2;
  };
  return '#' + to2(hue2rgb(p, q, hh + 1 / 3)) + to2(hue2rgb(p, q, hh)) + to2(hue2rgb(p, q, hh - 1 / 3));
}

function shiftHue(h: number, delta: number): number {
  return (h + delta + 360) % 360;
}

function toneForLight(h: number, s: number, l: number): Hsl {
  return { h: h, s: clamp(s, 0, 100), l: clamp(l, 0, 100) };
}

function toneForDark(h: number, s: number, l: number): Hsl {
  const darkL = clamp(l + (85 - l) * 0.55, 55, 92);
  return { h: h, s: clamp(s, 0, 100), l: darkL };
}

/**
 * Material DynamicScheme 简化版:从种子色生成主/次/第三色。
 * 变体规则参考 com.google.android.material.color.utilities.Variant
 */
export interface SurfaceTriple {
  bg: string;
  surface: string;
  surfaceVariant: string;
}

/**
 * 按 Material DynamicColors 的 HCT tone 规则生成背景三色:
 * 暗色 background tone 11 / surface tone 17 / surfaceVariant tone 34
 * 亮色 background tone 98 / surface tone 99 / surfaceVariant tone 90
 * 色相绑定种子色;暗色提高 chroma,使自定义色的色调在背景上明显可见
 */
export function generateBackgroundScheme(seed: string, isDark: boolean): SurfaceTriple {
  const base = hexToHsl(seed);
  const h = base.h;
  if (isDark) {
    return {
      bg: hslToHex(h, 35, 11),
      surface: hslToHex(h, 35, 17),
      surfaceVariant: hslToHex(h, 40, 34)
    };
  }
  return {
    bg: hslToHex(h, 6, 98),
    surface: hslToHex(h, 4, 99),
    surfaceVariant: hslToHex(h, 8, 90)
  };
}

export function generateVariantScheme(seed: string, variant: string, isDark: boolean): ColorTriple {
  const base = hexToHsl(seed);
  const h = base.h;
  const s = base.s;
  const l = base.l;
  let primary: Hsl = { h: h, s: s, l: l };
  let secondary: Hsl = { h: shiftHue(h, 30), s: clamp(s * 0.75, 20, 90), l: l + 6 };
  let tertiary: Hsl = { h: shiftHue(h, -30), s: clamp(s * 0.6, 15, 80), l: l - 6 };
  switch (variant) {
    case 'tonal_spot':
      primary = { h: h, s: clamp(s * 0.5 + 12, 15, 60), l: clamp(l, 40, 78) };
      secondary = { h: shiftHue(h, 30), s: clamp(s * 0.35 + 8, 10, 45), l: clamp(l + 8, 45, 80) };
      tertiary = { h: shiftHue(h, -30), s: clamp(s * 0.3 + 6, 8, 40), l: clamp(l - 8, 35, 72) };
      break;
    case 'vibrant':
      primary = { h: h, s: 90, l: clamp(l, 45, 70) };
      secondary = { h: shiftHue(h, 30), s: 70, l: clamp(l + 4, 40, 68) };
      tertiary = { h: shiftHue(h, -30), s: 55, l: clamp(l - 4, 38, 62) };
      break;
    case 'expressive':
      primary = { h: shiftHue(h, 30), s: 85, l: clamp(l, 40, 72) };
      secondary = { h: shiftHue(h, 75), s: 65, l: clamp(l + 6, 45, 74) };
      tertiary = { h: shiftHue(h, -45), s: 70, l: clamp(l - 8, 35, 66) };
      break;
    case 'fidelity':
      primary = { h: h, s: s, l: l };
      secondary = { h: shiftHue(h, 30), s: clamp(s * 0.7, 15, 80), l: l + 4 };
      tertiary = { h: shiftHue(h, -30), s: clamp(s * 0.5, 10, 65), l: l - 4 };
      break;
    case 'rainbow':
      primary = { h: h, s: 55, l: clamp(l, 40, 72) };
      secondary = { h: shiftHue(h, 120), s: 55, l: clamp(l + 5, 42, 74) };
      tertiary = { h: shiftHue(h, -120), s: 55, l: clamp(l - 5, 36, 68) };
      break;
    case 'fruit_salad':
      primary = { h: h, s: clamp(s * 0.8 + 8, 25, 75), l: clamp(l, 40, 70) };
      secondary = { h: shiftHue(h, -45), s: clamp(s * 0.65 + 6, 20, 65), l: clamp(l + 5, 42, 72) };
      tertiary = { h: shiftHue(h, 45), s: clamp(s * 0.55 + 4, 15, 60), l: clamp(l - 6, 36, 66) };
      break;
    case 'neutral':
      primary = { h: h, s: 12, l: clamp(l, 40, 70) };
      secondary = { h: shiftHue(h, 30), s: 9, l: clamp(l + 6, 42, 72) };
      tertiary = { h: shiftHue(h, -30), s: 6, l: clamp(l - 6, 36, 66) };
      break;
    case 'monochrome':
      primary = { h: 0, s: 0, l: clamp(l, 40, 70) };
      secondary = { h: 0, s: 0, l: clamp(l + 8, 44, 74) };
      tertiary = { h: 0, s: 0, l: clamp(l - 8, 34, 64) };
      break;
    default:
      break;
  }
  const p = isDark ? toneForDark(primary.h, primary.s, primary.l) : toneForLight(primary.h, primary.s, primary.l);
  const sc = isDark ? toneForDark(secondary.h, secondary.s, secondary.l) : toneForLight(secondary.h, secondary.s, secondary.l);
  const t = isDark ? toneForDark(tertiary.h, tertiary.s, tertiary.l) : toneForLight(tertiary.h, tertiary.s, tertiary.l);
  return {
    primary: hslToHex(p.h, p.s, p.l),
    secondary: hslToHex(sc.h, sc.s, sc.l),
    tertiary: hslToHex(t.h, t.s, t.l)
  };
}
