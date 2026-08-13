# <p align="center">Tieba Lite (HarmonyOS)</p>

<div align="center">
    <p>极简的贴吧<strong>第三方</strong>客户端 · HarmonyOS 版</p>
</div>

## 说明

**本软件及源码仅供学习交流使用，严禁用于商业用途。**

基于开源项目 [TiebaLite](https://github.com/0ranko0P/TiebaLite) 改造的 HarmonyOS NEXT(Stage 模型)版本，使用 ArkTS + ArkUI 开发。

## 功能

- 首页关注流 / 发现(热门、贴吧、话题) / 通知 / 我的 四个主标签页
- 帖子详情、楼中楼、图片预览、视频播放与画中画
- 吧内搜索、全局搜索、搜索历史
- 多账号切换、偏好设置(主题、卡片样式、透明度、图片加载模式、FAB 等)
- 深浅色主题跟随系统

## 构建

1. 克隆仓库并使用 DevEco Studio(5.0+)打开

2. 配置签名(必需,否则无法安装到真机)

   参考 `build-profile.json5.example` 创建 `build-profile.json5` 并填入你自己的密钥库信息:

   - 在 DevEco Studio 中通过 `File > Project Structure > Signing Configs` 自动生成并勾选自动签名
   - 或手动复制 `build-profile.json5.example` 为 `build-profile.json5`，填写 `storeFile` / `storePassword` / `keyAlias` / `keyPassword` / `profile` / `certpath`

3. 构建

   ```shell
   hvigorw assembleHap --mode module -p module=entry@default -p product=default -p buildMode=release
   ```

   产物位于 `entry/build/default/outputs/default/`。

## 注意

- `build-profile.json5`、`*.p12`、`*.cer`、`*.pem`、`*.p7b` 等签名相关文件已被 `.gitignore` 忽略，**切勿提交**(其中包含明文密钥库密码)
- 使用贴吧官方公开 API，登录凭证仅保存在本地

## 友情链接

+ [0ranko0P/TiebaLite: 原 Android 版](https://github.com/0ranko0P/TiebaLite)
+ [Starry-OvO/aiotieba: Asynchronous I/O Client for Baidu Tieba](https://github.com/Starry-OvO/aiotieba)
