# DeepSeek Harness Desktop — 安装包镜像

本仓库用于存放 **DeepSeek Harness 桌面版** 的官方安装包副本，方便在无法直接访问官方下载域名的网络环境下获取安装文件。

> ⚠️ **这是非官方镜像仓库。** 与 DeepSeek 官方无任何隶属或背书关系。
> 能够访问官方渠道时，**请优先从官方渠道下载**。

---

## 发布目的

1. **网络可达性**：部分企业/校园网络仅放行白名单域名，官方下载站点不在名单内，导致无法取得安装包。本仓库提供一份在这些环境下可达的副本。
2. **可复现性**：随包发布 SHA-256 校验值，任何人都能验证下载到的文件与镜像内容一致、未被篡改。
3. **归档**：预览版（`rc` 版本）在官方渠道更新后往往不再提供，此处保留存档。

## 安装包说明

| 文件 | 平台 | 大小 | 用途 |
| --- | --- | --- | --- |
| `deepseek-harness-0.1.7-rc.2-mac-arm64.dmg` | macOS 13.0+ / Apple Silicon (arm64) | 351 MB | macOS 磁盘映像。打开后把 DeepSeek Harness 拖入「应用程序」完成安装 |
| `deepseek-harness-0.1.7-rc.2-win-x64.exe` | Windows 10/11 x64 | 275 MB | Windows 安装程序（NSIS）。双击后按向导完成安装 |

两个文件均由官方地址 `download.deepseek.com` 取得，未经修改，SHA-256 与官方原文一致（见 [校验值](#校验值)）。官方直链见下一节。

**平台限制**：macOS 包仅支持 Apple Silicon（M 系列芯片），Intel Mac 无法使用，请另行获取 x64 版本。Windows 包仅支持 64 位系统。

## 官方下载渠道

**能访问下面地址时，请优先从官方下载，不要使用本镜像。**

| 平台 | 官方直链 |
| --- | --- |
| Windows x64 | <https://download.deepseek.com/dsh-desk/bin/win-x64/deepseek-harness-0.1.7-rc.2-win-x64.exe> |
| macOS arm64 | <https://download.deepseek.com/dsh-desk/bin/mac-arm64/deepseek-harness-0.1.7-rc.2-mac-arm64.dmg> |

其他官方来源：

- 上游仓库：<https://github.com/deepseek-ai/deepseek-harness>
- 官方发布页：<https://github.com/deepseek-ai/deepseek-harness/releases>

上述官方直链的下载产物与本仓库镜像**逐字节相同**（SHA-256 已比对一致），可任选其一。本镜像可能滞后于官方最新版本，请以官方为准。

## 版本信息

- 版本号：`0.1.7-rc.2`（预览版）
- macOS Bundle ID：`com.deepseek.dsh`
- Windows 安装程序类型：NSIS self-extracting archive
- 镜像建立日期：2026-09-28

## 校验值

下载后请务必校验，确认文件完整且未被篡改。

```
SHA-256
30909618ec09559448fc5bb28dffd7111c66e30f9b2142165fb9a812896f6607  deepseek-harness-0.1.7-rc.2-mac-arm64.dmg
0cf065dc2fc56456448620230581a9072477f0b2562bbc4e1709cdaedd3ceb86  deepseek-harness-0.1.7-rc.2-win-x64.exe
```

**macOS / Linux：**

```bash
shasum -a 256 deepseek-harness-0.1.7-rc.2-mac-arm64.dmg
```

**Windows（PowerShell）：**

```powershell
Get-FileHash .\deepseek-harness-0.1.7-rc.2-win-x64.exe -Algorithm SHA256
```

输出的哈希值必须与上表完全一致。**不一致请立即删除文件，不要安装。**

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

两个安装包均支持 **HTTP Range 断点续传**（实测返回 `206 Partial Content`），大文件下载中途断开**无需重头开始**：

```bash
# -C - 表示从已下载的部分继续
curl -L -C - -O https://github.com/LinJianKun/deepseek-harness-desktop-mirror/releases/download/v0.1.7-rc.2/deepseek-harness-0.1.7-rc.2-win-x64.exe
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

DeepSeek Harness 为开源项目，采用 **Apache License 2.0** 许可。

- 上游项目：[deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)
- 版权归属：Copyright © 2026 DeepSeek Harness
- 许可证全文见本仓库 [LICENSE](./LICENSE) 文件，第三方组件声明见 [NOTICE](./NOTICE)

本仓库以**未经修改的原始二进制形式**再分发上述安装包，依 Apache License 2.0 第 4 条关于二进制形式再分发的要求：

- 已随附完整许可证全文（`LICENSE`）；
- 已保留原始版权、专利、商标与归属声明（本节及 `NOTICE`）；
- 未对文件作任何修改——SHA-256 校验值可独立验证这一点。

若版权所有者认为本镜像不妥，请通过 Issue 联系，将立即移除相关文件。

## 免责声明

本仓库仅为网络可达性目的提供文件副本，不对软件本身的功能、安全性或适用性作任何担保。安装与使用风险由使用者自行承担。请以官方发布为准。
