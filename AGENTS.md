# Session Record

## BUILD NOTE
- Set `$env:JAVA_HOME = "C:\Program Files\Huawei\DevEco Studio\jbr"; $env:Path = "C:\Program Files\Huawei\DevEco Studio\jbr\bin;$env:Path"` before building.
- Build from project root: `& "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p module=entry@default -p product=default --no-daemon`
- (D:\DevEcoStudio5\tools\hvigor variant fails with "The root node is not yet available for build" — do not use.)
- Signed HAP output: `entry\build\default\outputs\default\entry-default-signed.hap`

## Changes Made

### VideoViewPage.ets — 全屏播放逻辑推倒重建 (2026-08)
- **根因**: 旧逻辑状态机过多(moov 探测、部分缓存直播、流式↔本地中途切换、4 种超时器、surface 重建无条件重建播放器),任何网络抖动就卡加载或失败。
- **新逻辑(简化)**:
  - 仅两个播放源:完整缓存文件(`getCachedPath` 带 .done 标记)优先 → `playLocal`;否则 `playStreaming` 直连 URL。**播放中不再切换缓存源**(缓存完成后留给下次进入用)。
  - 统一 `beginLoad`(gen + loading + 加载超时:本地 8s / 流式 20s)→ `handleLoadFailure`:本地失败 → invalidate 缓存 + 转流式;流式失败 → 重试 2 次(1.5s/4s)→ 错误界面。
  - `onSurfaceReady`:玩家已存在时先尝试重绑 surfaceId,不行才 `rebuildPlayerAt`(旧代码无条件 release+reinit)。
  - **删除**:fetchDuration/findBox/parseMp4Duration、subscribe 回调、maybePlayLocal/decidePlayback 旧版、switchToStreaming/fallbackToStreaming/reloadLocal、startLocalWatch、waitingForDownload 全套、progressive 探测全套、resumeTargetSec/streamResumeSec/lastDlPct/cacheUnsub 等字段。
- 保留:PiP、倍速、循环、静音、方向、进度条、信息面板、seek 定位(startSec,12s seekSafety 兜底)。
- 注意:预览组件 VideoPlayer.ets 仍保留自己的缓存/回退逻辑(用户未报预览问题,未动)。


### SearchRepo.ts
- Added `hasMore` property to search result structure

### SearchPage.ets
- Fixed user avatar/ID display: extract `user_list` from API response, build `userMap`, pass to `extractSearchResultsViaFrs` to fill in author info from `user_list`

### Post.ts (data model)
- Added `user_list?: Dict[]` field

### ThreadPage.ets
- Background opacity: all content area bg `0.08`, 楼中楼 (reply-in-reply) bg `0.22`
- Reply header (回复/只看楼主 toggle) made sticky: moved header Row outside Scroll, above the List
- "全部回复" → "回复" text, added "只看楼主" toggle switch
- 楼中楼 "查看xx条回复" changed from centered to left-aligned with padding
- Bottom action bar: removed 💬 bubble icon, click reply text to open reply dialog; added collect (收藏) button; 👍 thumbs up with count
- Menu (更多) simplified: only 分享/复制链接/举报
- Reply dialog: added risk warning text at top
- Status bar + nav bar background color synced with page background color

### HomePage.ets
- Unified home page background with forum list background (`Column` bg → `0.06`)
- Search box background deepened (`0.15` → `0.20`)
- Added 足迹 (history) capsule chips below search box (with X delete button)
- Forums grid adjusted, forum icons made slightly larger (30 → 32)

### SearchPage.ets (Search refactoring)
- Tabs changed from `['帖子', '贴吧', '用户']` to `['全部', '主题帖']`
- Added sort dropdown below tabs with `相关性在前` (sortMode=2) and `最新评论在前` (sortMode=1) options, using ▾ icon
- "全部" tab: fetches threads + forums + users in parallel via Promise.all, renders with section headers (帖子/贴吧/用户)
- "主题帖" tab: fetches only thread results
- API calls now pass dynamic sortMode parameter (searchPost uses `sort_mode`, searchThread passes `sort_mode` in query)
- Separate arrays: `threadResults`, `forumResults`, `userResults` instead of single `results`
### HttpClient.ts
- `simpleGet()` fixed: added `Cookie: ka=open` header, `expectDataType: http.HttpDataType.OBJECT`, device fingerprint params (cuid, client_version, model, etc.), account BDUSS/STOKEN params, and better JSON parse error handling
### MixedTiebaApiImpl.ts (searchForum/searchUser)
- Added `error_code`/`errno` checking before processing response
- Support for response where `data` is an array (treat as list directly)
- More fallback key names for list extraction
### ITiebaApi.ts / MixedTiebaApiImpl.ts / SearchRepository.ts
- `searchPost()` and `searchThread()` signatures updated to accept `sortMode: number` parameter
### TopicDetailPage.ets
- Updated `searchThread()` calls to pass `2` (relevance) as sortMode

### FavoritePage.ets
- Added support for `open_type` in thread items (some forum entries use `open_type` field)

### ForumPage.ets
- `extractThreads()` now accepts optional `userMap: Map<string, Dict>` parameter
- `loadMore()` now extracts `user_list` from FRS API response, builds `userMap`, passes to `extractThreads()`
- Inside `extractThreads()`, if thread author has no name/portrait, look up from `userMap` via `author_id`
- Added `forumId` field extraction from page data + fallback for thread `forumId`
- Sticky threads (置顶贴) card: limited to 3 visible by default, added expand/collapse toggle
  - Added `topExpanded: boolean` state
  - ForEach source changed to `this.topExpanded ? this.topThreads : this.topThreads.slice(0, 3)`
  - Added "更多▼" / "收起▲" row when > 3 sticky threads
  - Divider logic adjusted for collapsed/expanded states

### PbContentRender.ets (post page images)
- Replaced `NetworkImage` with raw `Image` for type=1 (static) and type=3 (gif) images
- Removed fixed height constraint (400/500px) – images now display at **full width with natural height** (`objectFit: ImageFit.Contain`, no width/height restriction)
- Removed `isLongPic()` method – all images treated equally
- Click handler now passes **ALL image URLs** from the post content (not just clicked one) via `collectImageParams(index)`
- Removed `NetworkImage` import

### ThreadImageGrid.ets (new file – thread card image previews)
- **1 image**: 190vp-tall × full width container – if image dimensions available and wider than 16:9 (`h/w <= 1.78`) uses `ImageFit.Contain` (show all); otherwise `ImageFit.Cover` (center crop)
- **2 images**: Side by side, each `.layoutWeight(1)`, `ImageFit.Cover`, `borderRadius(8)` + `clip(true)` 
- **3+ images**: Left image `.layoutWeight(2)` (full height), right column `.layoutWeight(1)` with 2 stacked `.layoutWeight(1)` cells
- **4+ images**: Same as 3, but third cell shows `+N` badge (semi-transparent black bg) at bottom-right
- Each cell has individual `onClick` → `PhotoViewPage` with all URLs

### ThreadCard.ets
- Replaced old image rendering (vertical stack of 3×`NetworkImage`, 160px each) with `ThreadImageGrid`
- Added `resolveMediaUrls()` helper for `media` → URL strings with `https:` prefix fallback
- Removed `NetworkImage` import

### PhotoViewPage.ets
- Fixed param parsing: reads `params.urls` and `params.index` directly from `router.getParams()` (was wrongly looking for nested `data` JSON string, making image viewer broken)

### ThreadImageGrid.ets (component)
- Extracted from ThreadCard for clean separation of image grid layout logic
- Uses `layoutWeight` for proportional sizing instead of hardcoded percentages

### Agree/like count fixes
- **Problem**: API often returns `agree` sub-object with `agree_num` (underscore) instead of `agreeNum` (camelCase). Code in ThreadCard, ThreadPage, UserProfilePage, SubPostsPage only checked camelCase `agreeNum` inside the `agree` sub-object, missing the underscore variant.
- **ThreadCard.ets** `getAgreeCount()`: Added `'agree_num'` to `getNum()` call for `agree` sub-object lookups
- **ThreadPage.ets** `extractThreadInfo()`: Added `agree.agree_num` to both the firstPostData and thread-level `agree` field lookups
- **ThreadPage.ets** `formatAgreeText()`: Added `agree.agree_num` to the agree field chain
- **UserProfilePage.ets** `getAgreeCount()`: Added `'agree_num'` to `getNum()` for `agree` sub-object
- **SubPostsPage.ets** `getAgreeCount()`: Added flat `sub.agree_num` check
- **ForumPage.ets** `extractThreads()`: When extracting inner `thread_list[0]` as the thread item, the outer wrapper's `agree`, `agreeNum`, `agree_num` fields were lost — now copied from outer to inner via bracket notation

### ThreadPage Author Click Navigation
- `extractThreadInfo()` now returns `authorId` (from `author?.id || thread.author_id`) in the info dict
- First post (OP) author Avatar and name now have `.onClick()` → `UserProfilePage` passing `threadData.authorId`
- Per-reply-post author Avatar and name now have `.onClick()` → `UserProfilePage` passing `post.author_id || post.authorId`

### UserProfilePage Post/Reply Counts
- **UserProfileRepository.ts** `loadProfile()`: Swapped API call order — now tries **proto API** (`userProfile` with `needPostCount: 1`) **first** (which returns `post_num` / `reply_num`), falls back to mini API (`profile`) on failure. Previously the mini API was tried first, and the proto API (which has counts) was only called as an error fallback, so post/reply counts were almost always 0.

### NotificationsPage Fixes
- **Thread ID extraction**: `getThreadTitle()`, `getForumName()`, and `NotificationItem` onClick now fall back to check `item.source` and `item.thread` sub-objects when top-level fields aren't found (fixes agree/赞 notifications not navigating)
- **System notification navigation**: Added `onClick` to `SystemItem` with same nested-object fallback for `thread_id`
- **Removed forum name** display from notification items
- **Enlarged thread title**: Changed from 13px to 16px, added `FontWeight.Medium`, `backgroundColor(blendWithWhite(..., 0.08))`, padding, `borderRadius(4)`
- **UI tone matching**: Item backgrounds changed from `0.12` to `0.08` with `borderRadius(8)`, tab bar from `0.15` to `0.12`
- **SystemItem background**: Changed from `'#FFFFFF'` to `blendWithWhite(..., 0.08)` with `borderRadius(8)`, `margin({ bottom: 1 })`

### UserTabPage Menu Cleanup
- Removed 7 non-functional menu items (签到设置, 屏蔽设置, 账号管理, 隐私设置, 习惯设置, UI 设置, 关于) that had empty `() => {}` click handlers
- Added 💾 我的收藏 → `ThreadStorePage`, 📖 浏览记录 → `HistoryPage`
- Kept: 🎨 主题 → `AppThemePage`, ⚙️ 全部设置 → `SettingsPage`

### Dark Mode Fix (ThemeProvider + EntryAbility + UserTabPage + AppThemePage)
- **ThemeProvider.ts**: Added `systemDark` field + `setSystemDark(isDark)` for external system dark mode updates. `isDarkTheme()` now correctly returns `systemDark` when in `FOLLOW_SYSTEM` mode. Added `setDarkMode(mode)` and `setAmoled(v)` methods that persist + sync to AppStorage. `syncToAppStorage()` now uses `isDarkTheme()` for `primaryColor`, and stores `darkMode` / `isDarkTheme` keys.
- **EntryAbility.ets**: Detects system `colorMode` on startup via `context.config`, calls `ThemeProvider.setSystemDark()`. Added `onConfigurationUpdate()` override to listen for system dark mode changes.
- **UserTabPage.ets**: Replaced inert dark mode toggle (`@State darkMode: boolean` Toggle) with a 3-option selector: 跟随系统 / 浅色模式 / 深色模式. Uses `@StorageLink('darkMode')` for reactive UI + `ThemeProvider.setDarkMode()` to persist.
- **AppThemePage.ets**: AMOLED toggle now uses `ThemeProvider.setAmoled()` instead of writing to `PreferencesManager` directly.

## Build Fixes & HAP Generation

### Build command
```
D:\DevEcoStudio5\tools\hvigor\bin\hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```
Then `run_pack.bat` bundles the unsigned HAP.

### Fixes applied to unblock CompileArkTS
- **HomePage.ets:110**: Changed `account.user_id || account.userId || account.id` → `account.uid`
- **TopicDetailPage.ets:134**: Moved `const topicImg = getStr(...)` inline inside `@Builder`
- **ThreadPage.ets:364**: Cast `newVal.height as number`
- **ThreadPage.ets:374**: Wrapped `this.postItem(post)` in `Column()` for `.transition()`
- **ThreadPage.ets:5**: Changed `@ohos.multimedia.picker` → `@ohos.file.picker`
- **ThreadPage.ets:986-988**: Changed `new TextEncoder()` → `new util.TextEncoder()`
- **ThreadPage.ets:1021-1022**: Cast empty object literals `{}` → `{} as Record<string, Object>`
- **ThreadPage.ets:944-952**: Removed `Record<string, Object>` cast, access `.photoUris` directly

### Result
`CompileArkTS` passes with 0 errors. Unsigned HAP at `entry/build/default/outputs/default/entry-default-unsigned.hap` (7.2 MB).

---

## Session 2

### Key Architecture Decisions
- **Module-level var over AppStorage** for `@Entry` page flags: `_storeInitialLoadDone` persists across page push/pop without lifecycle resets
- **Every page with `pageTransition()` must have `onBackPress()` → `NavigationHelper.markBack()`**: Without it, system back gesture uses `SlideEffect.Right` (forward animation) instead of `SlideEffect.Left` (back animation)
- **`/c/c/post/addstore` requires JSON `data` field** (not individual params): Android sends `[{"pid":"threadId","tid":"postId","status":"0","type":"0"}]`. `/c/c/post/rmstore` uses `tid` param, not `thread_id`
- **Leave `tbs` out of explicit params**: `HttpClient.post()` auto-injects latest `tbs` (line 217: `if (!(PARAM.TBS in formData))`). Explicit stale `tbs` prevents auto-inject → request fails
- **Emoji URL construction prefers numeric `id` over Chinese `text`/`c`**: Standard Tieba emoji image URL uses the numeric ID; bracket chars must be stripped before regex validation
- **SubPostsPage pagination**: Uses `checkHasMore(data)` checking `page.totalPage` / `has_more` instead of relying on `more.length === 0` (matches ThreadPage `isLastPage` pattern)
- **UserTabPage stats extraction**: Must match UserProfilePage's exact pattern — separate `if (!v || v === '0')` checks (not `||` short-circuit), plus brute-force `scanAllKeys` for fallback
- **ArkTS strict mode**: calling `async` function from non-async context without `void` silently drops the Promise; `Record<string, string>` must be `as Dict`; `@Builder` cannot contain `console.info` or assignments

### Pages Fixed

#### ThreadStorePage.ets — Infinite spinner on re-entry
- **Problem**: `AppStorage.Get<boolean>('storeInitialLoadDone')` resets between page push/pop for `@Entry` components → `loading` stays `true` forever
- **Fix**: Replaced with module-level `let _storeInitialLoadDone: boolean = false`. Added `else { this.loading = false; this.error = ''; }` when `_storeInitialLoadDone` is true.

#### NotificationsPage.ets — Agree tab blank / no content
- **Problem**: `getReplyer()` and `getContent()` extracted nothing from the agree tab API response because the response shape is unknown
- **Fix**: Added unconditional full JSON dump logging in `loadAgreePage()`. `getReplyer()` now brute-force scans every direct child object for user-like fields (id, name, portrait_name, etc.). `getContent()` scans sub-objects, arrays, and all string key values for content text.
- **ArkTS strict**: Changed `Record<string, string>` → `as Dict`; moved `console.info` from `@Builder` to `loadAgreePage`; removed `_loggedReplyerKeys` field (state not needed)

#### Navigation back animation (21 pages)
- **Fix**: Added `onBackPress() { NavigationHelper.markBack(); return false; }` to: HistoryPage, SearchPage, ForumSearchPage, WebViewPage, HotTopicListPage, TopicDetailPage, LoginPage, ThreadStorePage, PhotoViewPage, SubPostsPage, VideoViewPage, UserProfilePage, SettingsPage, AboutPage, UISettingsPage, AccountManagePage, FontSettingsPage, HabitsSettingsPage, PrivacySettingsPage, SignInSettingsPage, AppThemePage

#### MixedTiebaApiImpl.ts — Thread/Favorite store API format
- **Problem**: `addStore` sent individual `thread_id`/`post_id` params, `removeStore` used `thread_id` — API expected `data` JSON array / `tid` field. Both passed explicit `tbs` which could be stale/empty
- **Fix**: `addStore` now sends `data: JSON.stringify([{"pid":"threadId","tid":"postId","status":"0","type":"0"}])`. `removeStore` uses `tid: threadId`. Removed explicit `tbs` from both — `HttpClient.post()` auto-injects it

#### SubPostsPage.ets — Pagination limited to ~30 replies
- **Problem**: `loadSubPosts()` always used `page: 1` (hardcoded) → only first page loaded
- **Fix**: Changed to `this.page`. Added `this.page = 1` reset before load. Added `checkHasMore(data)` checking `page.totalPage` / `has_more`. `loadMore()` updates `this.page` and `hasMore` on success. Added `void` prefix to async calls in template and `aboutToAppear`

#### ThreadCard.ets — Video preview/thumbnail blank in post lists
- **Problem**: `getGridUrls()` only checked `firstPostContent`/`media`/`imageUrls` — list API responses use `_abstract`/`abstract` arrays with `type=1` (image) and `type=5` (video) items
- **Fix**: Refactored into `tryExtractUrls()` — adds catch-all `else` branch extracting URL from ANY item regardless of `type`. Added `tryScanTopLevel()` scans thread top-level keys for `video`/`cover`/`poster`/`thumbnail`/`pic` keywords as last resort

#### PbContentRender.ets — Emoji not rendering in post replies
- **Problem**: `getEmojiUrl()` only checked `text` field for emoji name, couldn't handle numeric `id` or `c` field. Chinese emoji names (like "微笑") aren't valid emoji IDs. API responses use `[id]` with brackets
- **Fix**: Added `item.c` to direct URL check. Changed priority from `text||c||id` to `id||c||text`. Strips brackets `[]【】「」『』《》（）()<>{}` from ID before regex validation. Handles `//` protocol-relative URLs

#### UserTabPage.ets — Stats show "-" instead of actual counts
- **Problem**: `tryExtractProfile` combined all field checks in one expression — `if (!v || v === '0')` short-circuits to fallback when any field is missing, instead of checking each field independently
- **Fix**: Changed to separate `if (!v || v === '0')` checks per field (matching UserProfilePage pattern). Added `scanAllKeys` brute-force scanning `rawUser`/`raw` for `thread`/`post`/`tiezi`/`帖子`/`fans`/`follower`/`粉丝`/`follow`/`concern`/`关注`/`following` keys. Added `void` prefix to `loadProfileStats()` calls

#### VideoViewPage.ets — Play/pause button too small
- **Fix**: Enlarged play triangle from 26×28 → 40×52 within 80px circle (was 64px). Enlarged pause bars from 6×26 → 8×32 with 12px gap. Single-click on center button already toggles play/pause; double-click on background retained

#### HomePage.ets / ThreadStorePage.ets / NotificationsPage.ets — Loading never resolves
- **Fix**: Added `else { this.loading = false; this.error = ''; }` when `initialDone` flag is true (was missing `else` branch — once `initialDone` became true, loading state never cleared)

#### Content bottom padding — Nav bar no longer floats
- **Problem**: Previous fix removed `expandSafeArea(BOTTOM)` and added bottom padding, but nav bar should float over content
- **Fix**: All 3 Lists in NotificationsPage and ExplorePage — removed bottom padding, restored content fills to bottom with floating nav bar overlaying

#### Settings pages — NavigationHelper import path depth
- **Problem**: 7 settings pages used `../../core/utils/NavigationHelper` but `pages/settings/` only needs `../../` to reach `ets/`
- **Fix**: Changed `../../` → `../../` (was `../../../`)

### New Issue Reported (Not Yet Fixed)
- **Blank content area on Discover/Notifications/Forum pages**: "下面这一条区域不显示内容" — a specific UI section/area renders blank on ExplorePage (发现页), NotificationsPage (通知页), and ForumPage (贴吧主页). Screenshot provided by user but model cannot display images. Requires investigation of common layout components across the three pages.

### Build Status
`CompileArkTS` passes with 0 errors. Unsigned HAP at `entry/build/default/outputs/default/entry-default-unsigned.hap`.
