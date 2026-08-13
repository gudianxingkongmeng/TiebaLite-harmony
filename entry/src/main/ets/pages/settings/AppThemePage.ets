import router from '@ohos.router';
import { NavigationHelper } from '../../core/utils/NavigationHelper';
import { pageBg, textPrimary, textTertiary, textAccent, dividerColor, surfaceVariant } from '../../core/utils/DataHelper';
import ThemeProvider from '../../core/theme/ThemeProvider';
import { BUILTIN_THEMES, ThemeDefinition, RECOMMENDED_COLORS } from '../../core/theme/ThemeColors';
import { VARIANTS, VariantDef, generateVariantScheme, ColorTriple } from '../../core/theme/ThemeVariant';
import { setPageStatusBar } from '../../core/utils/SystemBarHelper';

const MORE_COLORS: string[] = [
  '#FFFFFF', '#F2F3F5', '#D9DBE0', '#B0B3BB', '#8A8E96', '#666A73',
  '#000000', '#2F3136', '#4A4D54', '#9AA0A6', '#C4C7CC', '#E5E6E8',
  '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5', '#2196F3',
  '#03A9F4', '#00BCD4', '#009688', '#4CAF50', '#8BC34A', '#FFEB3B',
  '#FF9800', '#FF5722', '#795548', '#607D8B'
];

interface RgbChannel {
  label: string;
  val: number;
  color: string;
}

interface TripleSwatchConfig {
  primary: string;
  secondary: string;
  tertiary: string;
  size: number;
  highlight: boolean;
}

@Entry
@Component
struct AppThemePage {
  @StorageLink('isDarkTheme') @Watch('onIsDarkChange') isDark: boolean = false;
  @StorageLink('primaryColor') @Watch('onPrimaryChange') primaryColor: string = '#4477E0';
  @StorageLink('customColor') customColor: string = '';
  @StorageLink('customVariant') customVariant: string = 'fidelity';
  @StorageProp('secondaryColor') secondaryColor: string = '#575E71';
  @StorageProp('tertiaryColor') tertiaryColor: string = '#5F5791';
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @State themes: ThemeDefinition[] = BUILTIN_THEMES;
  @State selectedIndex: number = 0;
  @State previewColor: string = '#4477E0';
  @State hexInput: string = '';
  @State bg: string = pageBg(false);
  @State r: number = 68;
  @State g: number = 119;
  @State b: number = 224;
  @State showColorSheet: boolean = false;
  async aboutToAppear(): Promise<void> {
    this.bg = pageBg(this.isDark);
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
    const config = ThemeProvider.getInstance().getConfig();
    this.selectedIndex = config.themeIndex;
    this.previewColor = config.customColor.length > 0 ? config.customColor : BUILTIN_THEMES[this.selectedIndex].swatch;
    this.hexInput = this.previewColor;
    this.rgbFromHex(this.previewColor);
  }
  onIsDarkChange(): void {
    this.bg = pageBg(this.isDark);
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bg);
  }
  onPrimaryChange(): void {
    this.bg = pageBg(this.isDark);
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, this.bg);
  }

  onPageShow(): void {
    void setPageStatusBar(getContext(this), this.primaryColor, this.isDark, pageBg(this.isDark));
  }

  build() {
    Stack() {
      Column()
        .width('100%').height('100%')
        .backgroundColor(this.bg)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      Column() {
        Row() {
          Image($r('app.media.ic_arrow_back')).width(22).height(22).fillColor(textPrimary(this.isDark)).onClick(() => router.back())
          Text('主题设置').fontFamily(this.appFontFamily).fontSize(16).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark)).margin({ left: 16 })
          Blank()
        }
      .padding(12).width('100%').backgroundColor(this.bg)

      Scroll() {
        Column() {
          Text('内置主题').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)
          ForEach(this.themes, (theme: ThemeDefinition, idx: number) => {
            Row() {
              this.ColorTripleSwatch({
                primary: this.isDark ? theme.primaryDark : theme.primaryLight,
                secondary: this.isDark ? theme.secondaryDark : theme.secondaryLight,
                tertiary: this.isDark ? theme.tertiaryDark : theme.tertiaryLight,
                size: 30,
                highlight: idx === this.selectedIndex && this.customColor.length === 0
              })
              Text(theme.name).fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
              Blank()
              if (idx === this.selectedIndex && this.customColor.length === 0) {
                Image($r('app.media.ic_check')).width(22).height(22).fillColor(this.primaryColor)
              }
            }
            .width('100%').height(54).padding({ left: 16, right: 16 })
            .onClick(async () => {
              this.selectedIndex = idx;
              await ThemeProvider.getInstance().setThemeIndex(idx);
              this.previewColor = BUILTIN_THEMES[idx].swatch;
              this.hexInput = this.previewColor;
              this.rgbFromHex(this.previewColor);
              this.showColorSheet = false;
              if (this.customColor.length > 0) {
                await ThemeProvider.getInstance().setCustomColor('');
              }
            })
            Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 56 })
          })

          Row() {
            this.ColorTripleSwatch({
              primary: this.customColor.length > 0 ? this.customColor : BUILTIN_THEMES[this.selectedIndex].swatch,
              secondary: this.customColor.length > 0 ? this.getCustomScheme().secondary : BUILTIN_THEMES[this.selectedIndex].secondaryLight,
              tertiary: this.customColor.length > 0 ? this.getCustomScheme().tertiary : BUILTIN_THEMES[this.selectedIndex].tertiaryLight,
              size: 30,
              highlight: this.customColor.length > 0
            })
            Text('自定义').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark)).margin({ left: 12 })
            Blank()
            if (this.customColor.length > 0) {
              Image($r('app.media.ic_check')).width(22).height(22).fillColor(this.primaryColor)
            }
          }
          .width('100%').height(54).padding({ left: 16, right: 16 })
          .onClick(() => {
            this.previewColor = this.customColor.length > 0 ? this.customColor : BUILTIN_THEMES[this.selectedIndex].swatch;
            this.hexInput = this.previewColor;
            this.rgbFromHex(this.previewColor);
            this.showColorSheet = true;
          })
          Divider().height(1).color(dividerColor(this.isDark)).margin({ left: 56 })

          Text('变体预览').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).width('100%').padding(16)
          Row() {
            this.ColorTripleSwatch({ primary: this.primaryColor, secondary: this.secondaryColor, tertiary: this.tertiaryColor, size: 36, highlight: false })
            Text('当前主题三色方案').fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).margin({ left: 12 })
            Blank()
          }.width('100%').padding({ left: 16, right: 16 }).height(48)
        }
        .width('100%').padding({ bottom: 32 }).backgroundColor(this.bg)
      }
        .scrollBar(BarState.Off)
      .width('100%').layoutWeight(1)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
    }
    .width('100%').height('100%').backgroundColor(this.bg)
    .bindSheet($$this.showColorSheet, this.colorSheetBuilder(), {
      height: SheetSize.LARGE,
      showClose: false,
      backgroundColor: Color.Transparent
    })
  }

  onBackPress(): boolean {
    NavigationHelper.markBack();
    return false;
  }

  @Builder
  ColorTripleSwatch(config: TripleSwatchConfig) {
    Column() {
      Row() {
        Column().width('50%').height('100%').backgroundColor(config.primary)
        Column().width('50%').height('100%').backgroundColor(config.secondary)
      }
      .width('100%').height('50%')
      Column().width('100%').height('50%').backgroundColor(config.tertiary)
    }
    .width(config.size).height(config.size)
    .borderRadius(8)
    .clip(true)
    .border({
      width: config.highlight ? 2.5 : 1,
      color: config.highlight ? this.primaryColor : (this.isDark ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.2)')
    })
  }

  @Builder
  VariantCell(variant: VariantDef) {
    Column({ space: 4 }) {
      this.ColorTripleSwatch({
        primary: generateVariantScheme(this.previewColor, variant.key, this.isDark).primary,
        secondary: generateVariantScheme(this.previewColor, variant.key, this.isDark).secondary,
        tertiary: generateVariantScheme(this.previewColor, variant.key, this.isDark).tertiary,
        size: 34,
        highlight: false
      })
      Text(variant.name).fontFamily(this.appFontFamily).fontSize(12).fontColor(
        this.customVariant === variant.key ? textAccent(this.primaryColor, this.isDark) : textTertiary(this.isDark)
      )
    }
    .onClick(() => { void this.applyVariant(variant.key); })
  }

  @Builder
  colorSheetBuilder() {
    Column() {
      Row() {
        Text('选择主题色').fontFamily(this.appFontFamily).fontSize(17).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
        Blank()
        Text('关闭').fontFamily(this.appFontFamily).fontSize(15).fontColor(textTertiary(this.isDark)).onClick(() => { this.showColorSheet = false; })
      }
      .width('100%').height(46).padding({ left: 4, right: 4 })

      Scroll() {
        Column() {
          Row() {
            this.ColorTripleSwatch({
              primary: generateVariantScheme(this.previewColor, this.customVariant, this.isDark).primary,
              secondary: generateVariantScheme(this.previewColor, this.customVariant, this.isDark).secondary,
              tertiary: generateVariantScheme(this.previewColor, this.customVariant, this.isDark).tertiary,
              size: 40,
              highlight: false
            })
            Text(this.previewColor.toUpperCase())
              .fontFamily(this.appFontFamily).fontSize(14).fontColor(textTertiary(this.isDark)).margin({ left: 10 })
            Blank()
            Text('恢复默认').fontFamily(this.appFontFamily).fontSize(14).fontColor(textAccent(this.primaryColor, this.isDark))
              .onClick(() => { void this.clearCustomColor(); })
          }
          .width('100%').height(52)

          Text('推荐色').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 4, top: 8, bottom: 2 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(RECOMMENDED_COLORS, (c: string) => {
              Circle().width(36).height(36).fill(c)
                .stroke(this.previewColor.toUpperCase() === c ? this.primaryColor : (this.isDark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.2)'))
                .strokeWidth(this.previewColor.toUpperCase() === c ? 3 : 1)
                .margin(7)
                .onClick(() => { this.applyCustomColor(c); })
            }, (c: string) => c)
          }
          .width('100%').padding({ top: 4, bottom: 8 })

          Text('色调变体').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 4, top: 4, bottom: 2 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
            ForEach(VARIANTS, (v: VariantDef) => {
              this.VariantCell(v)
            }, (v: VariantDef) => v.key)
          }
          .width('100%').padding({ top: 4, bottom: 8 })

          Text('更多颜色').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 4, top: 4, bottom: 2 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
            ForEach(MORE_COLORS, (c: string) => {
              Circle().width(32).height(32).fill(c)
                .stroke(this.previewColor.toUpperCase() === c ? this.primaryColor : (this.isDark ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.2)'))
                .strokeWidth(this.previewColor.toUpperCase() === c ? 3 : 1)
                .margin(6)
                .onClick(() => { this.applyCustomColor(c); })
            }, (c: string) => c)
          }
          .width('100%').padding({ top: 4, bottom: 8 })

          Text('RGB 调节').fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).width('100%').padding({ left: 4, top: 4, bottom: 2 })

          ForEach(this.getRgbChannels(), (ch: RgbChannel) => {
            Row() {
              Text(ch.label).fontFamily(this.appFontFamily).fontSize(15).fontWeight(FontWeight.Bold).fontColor(ch.color).width(20)
              Slider({ value: ch.val, min: 0, max: 255, step: 1 })
                .layoutWeight(1).margin({ left: 6, right: 10 }).height(28)
                .onChange((value: number, mode: SliderChangeMode) => {
                  this.updateChannel(ch.label, Math.round(value));
                  if (mode === SliderChangeMode.End) {
                    void ThemeProvider.getInstance().setCustomColor(this.previewColor);
                  }
                })
              Text(ch.val.toString())
                .fontFamily(this.appFontFamily).fontSize(13).fontColor(textTertiary(this.isDark)).width(32).textAlign(TextAlign.End)
            }
            .width('100%').height(40)
          }, (ch: RgbChannel) => ch.label)

          Row() {
            Text('色号').fontFamily(this.appFontFamily).fontSize(16).fontColor(textPrimary(this.isDark))
            Blank()
            TextInput({ text: this.hexInput, placeholder: '#RRGGBB' })
              .width(150).height(40).fontSize(15).textAlign(TextAlign.Center)
              .backgroundColor(surfaceVariant(this.isDark)).borderRadius(8)
              .fontColor(textPrimary(this.isDark))
              .onChange((v: string) => {
                this.hexInput = v.trim();
                this.tryApplyHex();
              })
          }
          .width('100%').height(52)
        }
        .width('100%').padding({ bottom: 16 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%').padding(16).backgroundColor(this.bg)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  getCustomScheme(): ColorTriple {
    return generateVariantScheme(this.customColor, this.customVariant, this.isDark);
  }

  getRgbChannels(): RgbChannel[] {
    return [
      { label: 'R', val: this.r, color: '#FF3B30' },
      { label: 'G', val: this.g, color: '#34C759' },
      { label: 'B', val: this.b, color: '#007AFF' }
    ];
  }

  rgbToHex(r: number, g: number, b: number): string {
    const to2 = (v: number): string => {
      const s = Math.max(0, Math.min(Math.round(v), 255)).toString(16).toUpperCase();
      return s.length === 1 ? '0' + s : s;
    };
    return '#' + to2(r) + to2(g) + to2(b);
  }

  rgbFromHex(hex: string): void {
    const m = /^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/.exec(hex);
    if (m) {
      this.r = parseInt(m[1], 16);
      this.g = parseInt(m[2], 16);
      this.b = parseInt(m[3], 16);
    }
  }

  updateChannel(label: string, value: number): void {
    if (label === 'R') {
      this.r = value;
    } else if (label === 'G') {
      this.g = value;
    } else {
      this.b = value;
    }
    this.previewColor = this.rgbToHex(this.r, this.g, this.b);
    this.hexInput = this.previewColor;
  }

  applyCustomColor(hex: string): void {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex)) return;
    this.previewColor = hex;
    this.hexInput = hex;
    this.rgbFromHex(hex);
    void ThemeProvider.getInstance().setCustomColor(hex);
  }

  async applyVariant(key: string): Promise<void> {
    await ThemeProvider.getInstance().setCustomVariant(key);
  }

  tryApplyHex(): void {
    if (/^#[0-9a-fA-F]{6}$/.test(this.hexInput)) {
      this.applyCustomColor(this.hexInput);
    }
  }

  async clearCustomColor(): Promise<void> {
    await ThemeProvider.getInstance().setCustomColor('');
    this.previewColor = BUILTIN_THEMES[this.selectedIndex].swatch;
    this.hexInput = this.previewColor;
    this.rgbFromHex(this.previewColor);
    this.showColorSheet = false;
  }

  pageTransition() {
    if (NavigationHelper.isFadeTransition()) {
      if (NavigationHelper.isBack) {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.94, y: 0.94 })
      } else {
        PageTransitionEnter({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 0.96, y: 0.96 })
        PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
          .opacity(0)
          .scale({ x: 1.04, y: 1.04 })
      }
    } else if (NavigationHelper.isBack) {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
    } else {
      PageTransitionEnter({ duration: 350, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Right)
      PageTransitionExit({ duration: 300, curve: Curve.FastOutSlowIn })
        .slide(SlideEffect.Left)
    }
  }
}
