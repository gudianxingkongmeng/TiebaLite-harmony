# TiebaLite OHOS 任务清单

## 已完成
- [x] 主题帖投票功能（PollCard 组件、protobuf 投票请求、投票显示与提交）
- [x] 主题帖投票信息提取（从 pbPage 响应中解码投票数据）
- [x] 搜索功能排序修复（改用 `/mo/q/search/thread` 接口 + `st` 排序参数，对齐安卓版）
- [x] 楼中楼自回复照片显示修复（添加楼中楼图片大图渲染，支持 type 1/3/20 图片提取与展示）
- [x] 贴吧主页悬浮按钮发帖修复（`loadThreads` 中从 API 响应提取 `forumId`，确保发帖到正确的贴吧）
- [x] 回复层主后停留在当前楼层（不再跳转到最后一页，`loadThread(this.page)` 重新加载当前页）
- [x] 楼中楼子回复页身份标签胶囊统一与主楼一致（fontSize、padding、borderRadius、margin 对齐主楼样式）
- [x] 楼中楼子回复页增加"楼主"身份标签（将楼主判断提到层主之前，楼主回复时优先显示"楼主"）
- [x] 最近贴吧记录扩展（创建 `RecentForumHelper` 公共工具，发现页/搜索页/浏览记录/收藏页/通知页/帖子页/ThreadCard 点击进入贴吧都会记录）
- [x] 最近贴吧叉号显示修复（空ID贴吧不再错误显示叉号，`pendingDeleteForumId` 加空值判断；离开页面自动取消叉号显示）
- [x] 楼中楼子回复页移除回复按钮（避免与回到顶部按钮重叠，点击层主内容即可弹出回复窗）
- [x] 楼中楼子回复页点击最顶层主内容弹出回复窗（`parentPostItem` 内容区域添加 onClick 回调）
- [x] 楼中楼图片显示为链接样式（改为蓝色下划线"图片"文字，点击弹出图片查看，返回后恢复）
- [x] 未登录时推荐页显示内容（移除 `loadPersonalizedWithFallback` 中的登录检查，未登录也尝试加载推荐）
- [x] 全屏沉浸式布局（`EntryAbility` 启用 `setWindowLayoutFullScreen`，新增 `TopInsetHelper` 统一处理状态栏/手势区安全距离）
- [x] 状态栏与底部导航遮挡修复（首页、帖子页、发现、我的、贴吧、子回复、历史、收藏、用户资料等页面按 `topInset` 补偿）
- [x] 我的页顶部玻璃栏上移、底部退出登录按钮避开导航条
- [x] 关注/粉丝页玻璃容器合并（消除头部与列表独立模糊层的接缝）
- [x] 热门话题页浮层玻璃与占位修复
- [x] 悬浮按钮可拖拽（新增 `FabPositionManager`，发现页/发帖 FAB 支持拖拽、边界限制与位置持久化）
- [x] 悬浮按钮玻璃化并与「玻璃透明度」设置联动（设置项文案改为「玻璃透明度」，持久化 key 保持 `header_alpha`）
- [x] 新增「重置悬浮按钮位置」入口（通过 `fabPositionResetTick` 即时复位）
- [x] 帖子页回顶按钮统一为公共 `BackToTopButton` 组件，清理旧内联实现
- [x] 历史页改为 `List + LazyForEach` 懒加载（解决最多 500 条记录全量渲染导致的点击卡顿）
- [x] 通知页跳转修复（仅存在 `quote`/`re_floor` 字段才进入楼中楼页，普通通知进入帖子页；`postId` 与 `subPostId` 分开提取）
- [x] 收藏楼层记录与跳转（服务端 `mark_pid`/`post_no`；楼中楼使用真实 `pid` 而非 `spid`；大楼层按页码估算后向后探测）
- [x] 收藏跳转后加载上一页（顶部「查看之前的楼层」入口，采用前插并按 `_postPosMap` 补偿滚动位置，保持当前楼层不动）
- [x] 退出收藏帖时询问是否更新收藏楼层
- [x] 网络空响应根因修复（`HttpClient` 使用 `HttpDataType.OBJECT` 时空 body 会静默变成 `undefined`，现改为识别空响应并重试 3 次，覆盖 GET/POST 全部接口）
- [x] 收藏页点赞数改为纯本地回填（原先为每条收藏并发请求 `/c/f/pb/page`，会瞬间打出上百请求导致空响应；`ThreadCard` 本就从 `Preferences` 读取点赞数）
- [x] 清理调试日志（移除 `[E1]`–`[E7]`、`[D*]`、`[JUMP]`、`[STORE]`、`[A14]`、WebView 生命周期等高频打印，保留 error 级真实故障上报）
- [x] 表情不显示修复（贴吧部分回复的 content 中 `text` 只给裸前缀如 `image_emoticon`，编号需由名称字段 `c` 反查。新增 `isBareEmojiPrefix()`；`registerEmoji` 不再写入裸前缀以避免覆盖正确映射；表情类型收窄为 `[2, 11]`（按 protobuf 定义 9=电话号、10=语音，原先被误当表情渲染成空白））
- [x] 搜索页状态栏玻璃（内容容器去掉 `padding top`，让固定顶栏能贴到 y=0 覆盖状态栏；内容占位补 `topInset`）
- [x] 搜索框玻璃化与搜索按钮缩小（`SearchPage` 与 `ForumSearchPage`，输入框高度 36、按钮 32）
- [x] 贴吧内搜索限定本吧（改用 `searchPost` 小程序端接口，`searchThread` 为 Web 端其 `kw` 对帖子搜索无效会返回全贴吧结果）
- [x] 帖子页图片与投票卡片左右对齐（改用 `constraintSize({maxWidth})` 使 padding 生效，`width('100%')` 会让 margin/padding 失效并溢出容器；图片比例取 `bsize` 字段）

## 未完成
- [ ] 楼中楼回复内的图片无法显示缩略图（pb 接口返回的 `sub_post_list` 中该回复 `content` 为 `type=0` 纯文本，图片被压缩成字面量 `[图片]`，无任何图片 URL；官方安卓版能显示缩略图，推测使用了额外的接口或字段，需继续排查）
- [x] 图片查看页双击放大（已解决，关键在于**不再争抢手势优先级**。此前失败的三种做法：① `GestureGroup(Exclusive)`/`disableSwipe`/`hitTestBehavior` 均无法让子组件手势压过 Swiper 内部横滑；② 用 `isZoomed` 条件切换组件树，导致捏合越过 1 倍瞬间承载手势的组件被销毁、手势中断；③ 覆盖层用 `Visibility.Hidden`，隐藏状态下 Image 不加载，显示瞬间是空白反而盖住了正常缩放的图片。最终方案：覆盖层**常驻**组件树、用 `opacity(0)` 保持渲染预加载图片、用 `hitTestBehavior` 单独控制触摸，可见时位于 Swiper 之上触摸根本到不了它。另修两处坐标问题：平移改用 `FingerInfo.globalX/Y` 绝对坐标（`event.offsetX` 在被 `scale` 压缩的局部空间，会导致跟随距离不足）；缩放改为围绕 `pinchCenterX/Y` 和双击点锚定。平移范围按 `objectFit(Contain)` 绘制尺寸计算，夹在图片边缘内）
- [ ] 帖子页回复导航条透明度与顶栏不一致（导航条在 `Scroll` 内跟随内容滚动，玻璃背后是正文；顶栏固定，背后是页面底色，故相同 alpha 下视觉深浅不同。曾尝试移出 Scroll 用 Stack 固定底部，因改动过大已回退。后续可选：① 保持现状仅做数值补偿；② 参考 Android 版 zzc10086/TiebaLite 帖子页回复栏的实现方式）
- [x] 发帖后整页刷新导致界面重载（`ThreadPage.sendReply` 改为调用 `refreshAfterReply(repliedPid)`：先用 `loadFloorPage` 只拉被回复楼层所在的那一页，把该楼层的新回复合并进 `this.posts`，不再调用 `loadThread` 全量刷新；页码、滚动位置、已展开楼层均保持不变。注意 `closeReplyWindow()` 会清零 `replyPostId`，需在关闭前取出。主贴回复（`repliedPid === 0`）或增量拉取失败时退回 `loadThread(page, true)` 静默刷新。`SubPostsPage` 的回复仍是全量刷新，后续可同样改为追加）