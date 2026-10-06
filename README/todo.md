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

## 未完成
- [ ] 热门页未登录只显示4个帖子（改为 protobuf 请求方式后仍不行，待排查）