import { Dict } from '../core/types/Dict';
import { getNum, getStr, blendWithBg, textPrimary, textSecondary, textTertiary, dividerColor, onPrimaryContainer, shadowColor } from '../core/utils/DataHelper';

@Component
export default struct PollCard {
  @StorageLink('primaryColor') primaryColor: string = '#4477E0';
  @StorageLink('isDarkTheme') isDark: boolean = false;
  @StorageLink('appFontFamily') appFontFamily: string = '';
  @StorageLink('fontScale') fontScale: number = 1.0;
  @Prop @Watch('onPollInfoChanged') pollInfo: Dict = {};
  selectedOptions: number[] = [];
  onVote: (options: number[]) => void = () => {};
  onVoteChange: (options: number[]) => void = () => {};
  @State sel: number[] = [];
  @State voting: boolean = false;
  @State optArr: Dict[] = [];
  @State pollTitle: string = '';
  @State pollTotal: number = 0;
  @State pollEndTime: number = 0;
  @State pollMulti: boolean = false;
  @State polled: boolean = false;

  aboutToAppear(): void {
    this.syncFromPoll();
  }

  onPollInfoChanged(): void {
    this.syncFromPoll();
  }

  private syncFromPoll(): void {
    let arr: Dict[] = [];
    try {
      if (this.pollInfo) {
        const o = (this.pollInfo as Record<string, Object>)['options'];
        if (Array.isArray(o)) { arr = o as Dict[]; }
      }
    } catch (e) {
      arr = [];
    }
    this.optArr = arr;
    this.pollTitle = this.pollInfo ? (getStr(this.pollInfo, 'title') || '') : '';
    this.pollTotal = this.pollInfo ? getNum(this.pollInfo, 'total_poll', 'totalPoll', 'total_num', 'totalNum') : 0;
    this.pollEndTime = (this.pollInfo ? getNum(this.pollInfo, 'end_time', 'endTime') : 0) * 1000;
    this.pollMulti = this.pollInfo ? Number(this.pollInfo.is_multi ?? this.pollInfo.isMulti ?? 0) === 1 : false;
    try {
      const pv = this.pollInfo ? (this.pollInfo as Record<string, Object>)['polled_value'] as string : '';
      if (pv) {
        this.sel = pv.split(',').map((s: string) => parseInt(s)).filter((n: number) => !isNaN(n));
        this.polled = true;
      } else {
        this.sel = [];
        this.polled = false;
      }
    } catch (e) {
      this.sel = [];
      this.polled = false;
    }
  }

  private get title(): string {
    return this.pollTitle.length > 0 ? this.pollTitle : '投票';
  }

  private isExpired(): boolean {
    return this.pollEndTime > 0 && Date.now() >= this.pollEndTime;
  }

  private isChosen(id: number): boolean {
    return this.sel.indexOf(id) >= 0;
  }

  private toggleOption(id: number): void {
    if (this.polled || this.voting || this.isExpired()) return;
    const idx = this.sel.indexOf(id);
    if (idx >= 0) {
      this.sel = this.sel.filter((v: number) => v !== id);
    } else {
      if (!this.pollMulti) {
        this.sel = [id];
      } else {
        this.sel = [...this.sel, id];
      }
    }
    this.onVoteChange(this.sel);
  }

  private submit(): void {
    if (this.voting || this.sel.length === 0) return;
    this.voting = true;
    this.onVote(this.sel);
  }

  private formatPercent(num: number): string {
    if (this.pollTotal <= 0) return '0%';
    return Math.round(num / this.pollTotal * 100) + '%';
  }

  private getRatio(num: number): number {
    if (this.pollTotal <= 0) return 0;
    const r = num / this.pollTotal;
    return r > 1 ? 1 : r;
  }

  private formatEndTime(ms: number): string {
    if (ms <= 0) return '';
    const now = Date.now();
    const diff = ms - now;
    if (diff <= 0) return '已结束';
    const sec = Math.floor(diff / 1000);
    const day = Math.floor(sec / 86400);
    const hr = Math.floor((sec % 86400) / 3600);
    const min = Math.floor((sec % 3600) / 60);
if (day > 0) return day + '天后结束';
    if (hr > 0) return hr + '小时后结束';
    return min + '分钟后结束';
  }

  build() {
    Column() {
      Row() {
        Text(this.title)
          .fontFamily(this.appFontFamily).fontSize(Math.round(17 * (this.fontScale || 1.0))).fontWeight(FontWeight.Bold).fontColor(textPrimary(this.isDark))
          .padding({ left: 2 })
        Blank()
        if (this.pollTotal > 0) {
          Text(String(this.pollTotal) + ' 票')
            .fontFamily(this.appFontFamily).fontSize(Math.round(12 * (this.fontScale || 1.0))).fontColor(textSecondary(this.isDark)).margin({ left: 8 })
        }
        Text(this.pollMulti ? '多选' : '单选')
          .fontFamily(this.appFontFamily).fontSize(Math.round(12 * (this.fontScale || 1.0))).fontColor(textTertiary(this.isDark)).margin({ left: 8 })
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor(blendWithBg(this.primaryColor, 0.1, this.isDark))
          .borderRadius(10)
      }
      .width('100%')

      if (this.optArr.length === 0) {
        Text('投票选项数据为空').fontFamily(this.appFontFamily).fontSize(Math.round(13 * (this.fontScale || 1.0))).fontColor(textSecondary(this.isDark))
          .width('100%').textAlign(TextAlign.Center).padding({ top: 20, bottom: 16 })
      }

      ForEach(this.optArr, (opt: Dict, idx: number) => {
        Column() {
          Row() {
            Text(getStr(opt, 'text') || ('选项' + (idx + 1)))
              .fontFamily(this.appFontFamily).fontSize(Math.round(13 * (this.fontScale || 1.0)))
              .fontColor(this.isChosen(Number(opt.id)) ? onPrimaryContainer(this.isDark) : textPrimary(this.isDark))
              .fontWeight(this.isChosen(Number(opt.id)) ? FontWeight.Bold : FontWeight.Regular)
            Blank()
            if (this.polled || this.isExpired()) {
              Text(this.formatPercent(Number(opt.num)))
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * (this.fontScale || 1.0))).fontColor(textSecondary(this.isDark))
            } else if (this.isChosen(Number(opt.id))) {
              Row({ space: 4 }) {
                Text('✓')
                  .fontFamily(this.appFontFamily).fontSize(Math.round(12 * (this.fontScale || 1.0))).fontColor(this.primaryColor)
                Text(this.formatPercent(Number(opt.num)))
                  .fontFamily(this.appFontFamily).fontSize(Math.round(11 * (this.fontScale || 1.0))).fontColor(textSecondary(this.isDark))
              }
            } else {
              Text(this.formatPercent(Number(opt.num)))
                .fontFamily(this.appFontFamily).fontSize(Math.round(11 * (this.fontScale || 1.0))).fontColor(textSecondary(this.isDark))
            }
          }
          .width('100%')
        }
        .width('100%').padding({ left: 8, right: 8, top: 7, bottom: 7 })
        .borderRadius(9)
        .border({ width: 1, color: this.isChosen(Number(opt.id)) ? this.primaryColor : dividerColor(this.isDark) })
        .clip(true)
        .linearGradient({
          angle: 90,
          colors: [[this.isChosen(Number(opt.id)) ? blendWithBg(this.primaryColor, 0.4, this.isDark) : blendWithBg(this.primaryColor, 0.14, this.isDark), this.getRatio(Number(opt.num))], [this.isDark ? '#1E1E1E' : '#FFFFFF', this.getRatio(Number(opt.num))]]
        })
        .margin({ top: 8 })
        .onClick(() => { this.toggleOption(Number(opt.id)); })
      }, (opt: Dict, idx: number): string => String(opt.id ?? ('opt_' + idx)))

      if (this.pollEndTime > 0) {
        Text(this.formatEndTime(this.pollEndTime))
          .fontFamily(this.appFontFamily).fontSize(Math.round(12 * (this.fontScale || 1.0))).fontColor(textTertiary(this.isDark))
          .width('100%').textAlign(TextAlign.End).margin({ top: 10 })
      }

      if (!this.polled && !this.isExpired() && this.sel.length > 0) {
        Button(this.voting ? '投票中...' : '投票')
          .fontFamily(this.appFontFamily).fontSize(Math.round(14 * (this.fontScale || 1.0))).fontColor('#FFFFFF')
          .backgroundColor(this.primaryColor)
          .borderRadius(20)
          .width('100%').height(40).margin({ top: 12 })
          .onClick(() => { this.submit(); })
      }
    }
    .padding(12)
    .backgroundColor(blendWithBg(this.primaryColor, 0.06, this.isDark))
    .borderRadius(14)
    .border({ width: 1, color: dividerColor(this.isDark) })
    .shadow({ radius: 8, color: shadowColor(this.isDark), offsetY: 2 })
    // 用 maxWidth('100%') 而非 width('100%')：后者会撑满父容器使 margin 失效（ArkUI 行为），
    // 导致卡片贴到屏幕两侧。maxWidth 允许 margin 正常生效。
    .constraintSize({ maxWidth: '100%' })
    .margin({ left: 12, right: 12, top: 4, bottom: 12 })
  }
}
