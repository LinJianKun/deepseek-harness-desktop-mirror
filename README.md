# DeepSeek Harness Desktop — 安装包镜像

本仓库用于存放 **DeepSeek Harness 桌面版** 的官方安装包副本，方便在无法直接访问官方下载域名的网络环境下获取安装文件。

> ⚠️ **这是非官方镜像仓库。** 与 DeepSeek 官方无任何隶属或背书关系。
> 能够访问官方渠道时，**请优先从官方渠道下载**。

---

## 发布目的

1. **网络可达性**：部分企业/校园网络仅放行白名单域名，官方下载站点（`download.deepseek.com`）不在名单内，导致无法取得安装包。本仓库提供一份在这些环境下可达的副本。
2. **可复现性**：每个版本均发布 SHA-256 校验值，任何人都能验证下载到的文件与官方原文逐字节一致、未被篡改。
3. **归档**：官方渠道通常只保留最新版本，此处保留**全部历史版本**。

## 自动同步

本仓库由 GitHub Actions 自动同步上游发布：定时读取 [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的最新 tag，按版本号从官方下载地址取得对应安装包，校验后发布为本仓库的 Release，并自动更新本文件。

- 同步脚本：[scripts/sync-upstream.sh](./scripts/sync-upstream.sh)
- 工作流：[.github/workflows/sync-upstream.yml](./.github/workflows/sync-upstream.yml)
- 同步不会修改下载到的二进制，仅原样转发并记录 SHA-256。

### 启用工作流需要 workflow scope

**GitHub 不允许只具备 `repo` scope 的 token 推送 `.github/workflows/` 下的文件**（API 会返回 `404`，这是 GitHub 有意的模糊响应，并非路径错误）。若工作流尚未出现在仓库中，用以下任一方式启用：

**方式一：为本地 `gh` 补授权（推荐，一次性）**

```bash
gh auth refresh -h github.com -s workflow
```

在浏览器中确认后，再执行 `./release.sh` 即可推送工作流文件。

**方式二：网页端手动添加**

在仓库页面新建文件 `.github/workflows/sync-upstream.yml`，内容复制本地同名文件。注意不要改动路径与文件名，否则 Actions 不会识别。

启用后可在仓库 **Actions** 页面看到 `Sync upstream releases`，支持手动触发：

- 留空 → 同步上游最新版本
- 填版本号 → 同步指定版本
- 勾选"回填所有缺失的历史版本" → 补齐全部历史
- 勾选"仅探测" → 只检查不下载

> 定时任务为每 6 小时一次。GitHub 会在仓库连续 60 天无提交后停用定时工作流，因此工作流每次运行都会提交心跳文件 `heartbeat.txt` 以保持活跃。

## 平台说明

| 平台 | 安装包格式 | 适用系统 |
| --- | --- | --- |
| macOS arm64 | `.dmg` 磁盘映像 | macOS 13.0+，**仅 Apple Silicon（M 系列）**，Intel Mac 不可用 |
| Windows x64 | `.exe` 安装程序（NSIS） | Windows 10/11 **64 位** |

下载后请务必核对本文件中的 SHA-256 校验值。

---

## 版本列表

<!-- VERSION_TABLE_START -->
| 版本 | 发布日期 | 校验值 | 详情 |
| --- | --- | --- | --- |
| `0.2.0-rc.1` | 2026-09-28 | [SHA-256](#020-rc1) | [Release](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/tag/v0.2.0-rc.1) |
| `0.1.7-rc.2` | 2026-09-24 | [SHA-256](#017-rc2) | [Release](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/tag/v0.1.7-rc.2) |
| `0.1.7-rc.1` | 2026-09-23 | [SHA-256](#017-rc1) | [Release](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/tag/v0.1.7-rc.1) |
<!-- VERSION_TABLE_END -->

每个版本同时发布为本仓库的 [Release](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases)，可直接下载安装包。

## 各版本校验值

<!-- VERSION_DETAILS_START -->
<a id="020-rc1"></a>

### 0.2.0-rc.1

发布日期：2026-09-28

```
SHA-256
86cea83e41f516bbfb71d634bf62b965e5944723224abf41606ba8d636fe9858  deepseek-harness-0.2.0-rc.1-mac-arm64.dmg
9dd8538e554d3139998a8458e21c64a6f99470915cbf6cfd22bb71f356c7f399  deepseek-harness-0.2.0-rc.1-win-x64.exe
```

| 文件 | 平台 | 大小 | 下载 |
| --- | --- | --- | --- |
| `deepseek-harness-0.2.0-rc.1-mac-arm64.dmg` | macOS 13+ Apple Silicon | 352 MB | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.2.0-rc.1/deepseek-harness-0.2.0-rc.1-mac-arm64.dmg) |
| `deepseek-harness-0.2.0-rc.1-win-x64.exe` | Windows 10/11 x64 | 275 MB | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.2.0-rc.1/deepseek-harness-0.2.0-rc.1-win-x64.exe) |

<a id="017-rc2"></a>

### 0.1.7-rc.2

发布日期：2026-09-24

```
SHA-256
30909618ec09559448fc5bb28dffd7111c66e30f9b2142165fb9a812896f6607  deepseek-harness-0.1.7-rc.2-mac-arm64.dmg
0cf065dc2fc56456448620230581a9072477f0b2562bbc4e1709cdaedd3ceb86  deepseek-harness-0.1.7-rc.2-win-x64.exe
```

| 文件 | 平台 | 大小 | 下载 |
| --- | --- | --- | --- |
| `deepseek-harness-0.1.7-rc.2-mac-arm64.dmg` | macOS 13+ Apple Silicon | — | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.2/deepseek-harness-0.1.7-rc.2-mac-arm64.dmg) |
| `deepseek-harness-0.1.7-rc.2-win-x64.exe` | Windows 10/11 x64 | — | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.2/deepseek-harness-0.1.7-rc.2-win-x64.exe) |

<a id="017-rc1"></a>

### 0.1.7-rc.1

发布日期：2026-09-23

```
SHA-256
b762f3c3b0b4c273aa23088d24bdec111a845929a88b37a133d688c66921ec2d  deepseek-harness-0.1.7-rc.1-mac-arm64.dmg
08e8009592d97f41fe30ba5e8f8a7309b1f2ab3ba460feadd7a3d6dafb5e6de8  deepseek-harness-0.1.7-rc.1-win-x64.exe
```

| 文件 | 平台 | 大小 | 下载 |
| --- | --- | --- | --- |
| `deepseek-harness-0.1.7-rc.1-mac-arm64.dmg` | macOS 13+ Apple Silicon | — | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.1/deepseek-harness-0.1.7-rc.1-mac-arm64.dmg) |
| `deepseek-harness-0.1.7-rc.1-win-x64.exe` | Windows 10/11 x64 | — | [下载](https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.1/deepseek-harness-0.1.7-rc.1-win-x64.exe) |
<!-- VERSION_DETAILS_END -->

## 校验方法

**macOS / Linux：**

```bash
shasum -a 256 deepseek-harness-<版本>-mac-arm64.dmg
```

**Windows（PowerShell）：**

```powershell
Get-FileHash .\deepseek-harness-<版本>-win-x64.exe -Algorithm SHA256
```

输出的哈希值必须与「各版本校验值」中对应版本的记录完全一致。**不一致请立即删除文件，不要安装。**

## 官方下载渠道

官方安装包的 URL 遵循固定模式，可自行把 `<版本>` 与平台替换为所需值：

```
https://download.deepseek.com/dsh-desk/bin/<平台>/deepseek-harness-<版本>-<平台>.<扩展名>

平台：win-x64 → .exe      mac-arm64 → .dmg
```

例如：

- Windows x64：<https://download.deepseek.com/dsh-desk/bin/win-x64/deepseek-harness-0.1.7-rc.2-win-x64.exe>
- macOS arm64：<https://download.deepseek.com/dsh-desk/bin/mac-arm64/deepseek-harness-0.1.7-rc.2-mac-arm64.dmg>

**能访问 `download.deepseek.com` 时，请优先使用官方地址，不要使用本镜像。**

其他官方来源：

- 上游仓库：<https://github.com/deepseek-ai/deepseek-harness>
- 官方发布页：<https://github.com/deepseek-ai/deepseek-harness/releases>

本镜像的安装包与官方原文 **SHA-256 逐字节一致**，可任选其一。本镜像可能滞后于官方最新版本，请以官方为准。

## 网络白名单与下载中断排查

> 如果你的网络有域名白名单限制，**请先读这一节**——下载失败通常不是链接失效，而是重定向到了另一个域名。

两条下载路径所需的域名**不同**：

### 路径一：官方直链

```
download.deepseek.com  →  HTTP 200（直接返回文件，无重定向）
```

**只需放行 `download.deepseek.com` 一个域名。** 这是最省事的路径，若该域名可访问就不要用本镜像。

### 路径二：GitHub Release（本镜像）

```
github.com  →  HTTP 302  →  release-assets.githubusercontent.com  →  HTTP 200
```

**必须同时放行两个域名**：

| 域名 | 作用 | 只放行它会怎样 |
| --- | --- | --- |
| `github.com` | 仓库页面、Release 页面、发起下载 | 页面能打开、能搜索，但**点下载会被拦** |
| `release-assets.githubusercontent.com` | 实际传输安装包字节 | — |

**典型症状**：仓库能访问、能 `git clone` 源码，但点击安装包下载无反应或报错。这不是链接坏了——`github.com` 只负责发出 302 跳转，真正的文件字节由 `release-assets.githubusercontent.com` 传输。若 IT 只放行了 `github.com`，请把第二个域名一并申请。

### 下载中断了怎么办

安装包支持 **HTTP Range 断点续传**（实测返回 `206 Partial Content`），大文件下载中途断开**无需重头开始**：

```bash
# -C - 表示从已下载的部分继续
curl -L -C - -O https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/<tag>/<文件名>
```

浏览器下载同样可续传，重新点击下载通常会自动接着上次的进度。

### 快速自查

```bash
# 1. 官方下载域名是否可达
curl -sI --max-time 20 https://download.deepseek.com/dsh-desk/bin/win-x64/deepseek-harness-0.1.7-rc.2-win-x64.exe | head -1
# 期望：HTTP/2 200

# 2. GitHub 下载链路是否走通（含跳转，取最终状态码）
curl -sIL --max-time 20 -o /dev/null -w "%{http_code}\n" \
  https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.2/deepseek-harness-0.1.7-rc.2-win-x64.exe
# 期望：200（若为 403 / 无输出 / 连接超时，说明 release-assets.githubusercontent.com 被拦）
```

**注意**：不要用裸域名 `https://release-assets.githubusercontent.com` 测试可达性——它会返回 `404`，但这恰恰说明域名是通的（404 是服务器应答，屏蔽通常表现为超时或连接重置）。判断标准是**能否拿到 HTTP 状态码**，而非状态码是否为 200。

## 安装注意事项

- **macOS**：首次打开若提示"来自未识别开发者"，请在「系统设置 → 隐私与安全性」中允许，或右键点击应用选择「打开」。请勿为此关闭 Gatekeeper。
- **Windows**：若出现 SmartScreen 警告，请先核对上文 SHA-256 校验值，确认无误后再选择"仍要运行"。
- 本仓库中的二进制**未经任何修改、重打包或重新签名**。校验值即为证明。

## 版权与许可

DeepSeek Harness 上游项目采用 **MIT License** 许可。

- 上游项目：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
- 版权归属：Copyright (c) 2026 DeepSeek
- 许可证全文见本仓库 [LICENSE](./LICENSE) 文件，归属声明见 [NOTICE](./NOTICE)

本仓库以**未经修改的原始二进制形式**再分发官方安装包，依 MIT License 的要求：

- 已随附完整许可证全文，并保留原始版权声明（`LICENSE` 与 `NOTICE`）；
- 未对文件作任何修改——SHA-256 校验值可独立验证这一点；
- 安装包内打包的第三方组件遵循各自许可，详见上游仓库的 [THIRD_PARTY_NOTICES.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/THIRD_PARTY_NOTICES.md)。

> 说明：安装包内部包含若干以 Apache License 2.0 等许可授权的第三方依赖（如打包进 Electron 运行时的 Node.js 生态组件）。这些属于上游的第三方声明范畴，**不代表 DeepSeek Harness 项目本身的许可**。

若版权所有者认为本镜像不妥，请通过 Issue 联系，将立即移除相关文件。

## 免责声明

本仓库仅为网络可达性目的提供文件副本，不对软件本身的功能、安全性或适用性作任何担保。安装与使用风险由使用者自行承担。请以官方发布为准。
