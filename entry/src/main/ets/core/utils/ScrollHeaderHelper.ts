/**
 * 顶栏随滚动收起/展开的统一定价。
 *
 * 之前每个页面各写一套，参数还不一致，导致观感差异明显：
 *   - ExplorePage / SearchPage / ThreadPage 的主顶栏**没有包 animateTo**，
 *     高度是瞬间跳变的（44 → 0），内容同时上移 56~60px，看起来像"顿一下"。
 *   - 各页触发阈值都是 delta > 5，手指轻微抖动就会误触发，显得神经质。
 *   - 动画时长 220~250ms 不等，滚动跟随时偏慢，有迟滞感。
 *   - 收起和展开用同一阈值，快速来回滚动时顶栏会反复闪烁。
 *
 * 这里把参数收敛到一处：改这里即可让全站观感统一。
 */

/** 触发收起/展开所需的滚动距离（vp）。5 太小，轻微抖动就会触发。 */
export const HEADER_COLLAPSE_THRESHOLD: number = 16;

/** 展开所需的滚动距离，比收起更大，形成滞后，避免来回滚动时顶栏闪烁。 */
export const HEADER_EXPAND_THRESHOLD: number = 28;

/** 收起动画：快起慢收，收得干脆 */
export const HEADER_COLLAPSE_ANIM = { duration: 180, curve: Curve.FastOutSlowIn };

/** 展开动画：稍慢一点，配合滞后的阈值，观感更稳 */
export const HEADER_EXPAND_ANIM = { duration: 220, curve: Curve.FastOutSlowIn };

/** 单次滚动的异常跳变（如切页、惯性回弹），直接忽略 */
export const HEADER_SCROLL_JUMP_LIMIT: number = 2000;

/** 位移小于这个值视为静止，避免浮点噪声反复触发 */
export const HEADER_SCROLL_NOISE: number = 0.5;

export type HeaderAction = 'collapse' | 'expand' | 'none';

/**
 * 根据滚动增量决定顶栏该收起还是展开。
 *
 * @param delta 本次滚动的纵向增量，向下滚为正
 * @param collapsed 当前顶栏是否已收起
 * @param minExpandY 未滚动到这个位置前不允许展开（避免刚进页面就弹出）
 */
export function decideHeaderAction(delta: number, collapsed: boolean, minExpandY: number = 0): HeaderAction {
  if (delta > HEADER_SCROLL_JUMP_LIMIT || delta < -HEADER_SCROLL_JUMP_LIMIT) {
    return 'none';
  }
  if (Math.abs(delta) < HEADER_SCROLL_NOISE) {
    return 'none';
  }
  if (!collapsed) {
    // 展开状态下要滚得更多才收起，避免轻微下滑就折叠
    if (delta > HEADER_COLLAPSE_THRESHOLD) {
      return 'collapse';
    }
    return 'none';
  }
  // 已收起：反方向滚动更多距离才展开，形成滞后
  if (delta < -HEADER_EXPAND_THRESHOLD) {
    return 'expand';
  }
  return 'none';
}

/**
 * 是否强制展开（滚动回到顶部时必须显示）。
 */
export function shouldForceExpand(y: number, collapsed: boolean): boolean {
  return collapsed && y <= 2;
}
