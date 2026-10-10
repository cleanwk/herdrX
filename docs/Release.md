# Release

主分发使用已有的 `cleanwk/homebrew-tap`。应用仓库负责产出经过架构与完整性验证的 ZIP，tap 自己读取稳定 Release、验证资产摘要后更新 cask，无需跨仓库写权限的个人 token。

## 可选的 Apple 签名配置

默认不需要任何 Apple 凭据，Release Action 使用 ad-hoc 签名并如实记录 `notarized: false`。若以后启用 Apple 公证，在 `cleanwk/herdrX` 的 GitHub Settings 中配置 `release` environment。需要有效的 **Developer ID Application** 证书；Apple Development 证书不能替代它。

| 类型 | 名称 | 内容 |
| --- | --- | --- |
| Secret | `MACOS_CERTIFICATE_P12` | 包含私钥的 Developer ID Application PKCS#12 文件，以 base64 编码 |
| Secret | `MACOS_CERTIFICATE_PASSWORD` | P12 导出密码 |
| Variable | `MACOS_SIGN_IDENTITY` | `Developer ID Application: … (TEAMID)` 的完整身份名称 |
| Secret | `APPLE_ID` | 用于 Apple 公证的账户 |
| Variable | `APPLE_TEAM_ID` | Apple Developer Team ID |
| Secret | `APPLE_APP_PASSWORD` | Apple app-specific password |
| Variable，必需 | `SPARKLE_PUBLIC_KEY` | 与 `project.yml` 一致的 Sparkle Ed25519 公钥 |
| Secret，必需 | `SPARKLE_PRIVATE_KEY` | 对应的 Sparkle 私钥文本 |

Apple 凭据通过 GitHub Secrets 配置，不写进仓库；Apple 签名配置必须全部为空或全部完整，部分配置会报错。Ed25519 更新签名与 Apple 公证是两套独立机制：前者已配置，后者仍可选。Sparkle 公钥提交在 `project.yml`，私钥保存在 `release` environment 的 Secret 中；本机 Keychain 只保留恢复备份（account `io.github.cleanwk.herdrx`），CI 不依赖本机 Mac。不要为每个版本重新生成密钥。

Brew 与直接下载的安装都使用应用内 Sparkle 更新器。自动检查默认开启，运行期间每 24 小时检查；自动下载并安装默认关闭，用户开启后后台下载，退出应用时安装。手动入口位于 HerdrX 菜单和设置 → 关于，支持检查、下载、安装并重启，也显示上次检查时间与取消/失败状态。关闭自动检查不会禁用手动检查。Herdr 服务端会话独立运行，客户端退出不会终止它们。

Release 必须生成并验证签名安装包和签名 `appcast.xml`。`scripts/appcast.py` 校验构建/版本、最低系统、下载源、大小与 SHA-256，再通过 Sparkle 官方工具验证两份 Ed25519 签名，成功后才写入 `signed_updates: true` 和 `appcast_sha256`。缺少签名密钥、与内置公钥不匹配或任何验证失败都会阻止发布。参见 [Sparkle 发布文档](https://sparkle-project.org/documentation/publishing/)。

## 每个版本

1. 更新 `VERSION`，使用 `major.minor.patch`，提交修改。
2. 确认 CI 成功，推送与 VERSION 一致的 `vmajor.minor.patch` tag。
3. Release Action 构建 universal app、验证两种架构与签名；配置完整的 Apple 凭据时额外公证并 staple；成功后上传 ZIP、SHA256SUMS、release.json 和签名 appcast.xml。
4. 已有 tap 的更新 Action 每 15 分钟检查一次，或手动 Run workflow。它只接受稳定、明确标记公证状态、架构完整且 GitHub 资产 digest 与元数据一致的版本，禁止降级；签名更新元数据存在时，还校验 appcast 资产摘要，才写入 `auto_updates true`。旧版无签名更新元数据的 cask 继续兼容。
5. 用户可在应用内更新，或运行 `brew update && brew upgrade --cask herdrx`。指定 cask 的升级仍可用；不指定 cask 的批量 `brew upgrade` 默认跳过声明自更新的应用，需要 `--greedy` 才包含它们。

v0.1.7 未嵌入有效的更新公钥，需要先通过 Brew 或 Release 安装 v0.1.8，后续才能在应用内升级。

修改 tap 逻辑时，将 `distribution/tap/update.py` 和 `herdrx.yml` 同步到既有 tap 的 `scripts/update-herdrx.py` 与 `.github/workflows/herdrx.yml`，在相应版本发布前合并。首次稳定版本之前不生成占位 cask，也不填虚构校验值。计划任务要求工作流在 tap 默认分支上。tap 应用自己的 GITHUB_TOKEN 写入自身仓库。

## 本地验证

`scripts/build.sh` 默认生成 ad-hoc universal app，`scripts/package.sh` 输出开发预览及 `notarized: false` 元数据。本地产物尚不是 GitHub 稳定 Release，不会被 tap 自动读取；正式 tag 产物可以采用同样的 ad-hoc 签名。Ad-hoc 预览关闭 hardened runtime，以便加载没有 Developer ID team 的 Sparkle；正式签名构建启用 hardened runtime，并校验应用与 Sparkle 的签名 team 一致。

正式本地构建可设置 `SIGN_IDENTITY`，打包时设置 `NOTARIZE=1`、`APPLE_ID`、`APPLE_TEAM_ID` 和 `APPLE_APP_PASSWORD`。仅在公证 Accepted、staple 和 spctl 检查成功后写入 `notarized: true`。

CI runner 使用 GitHub 当前公布的 [xcode-27](https://github.com/actions/runner-images/blob/main/README.md)，构建工具固定在 Xcode 27 系列。流程不会在每次普通代码提交时发布用户版本；每个正式版本 tag 触发一次发布，PR 和默认分支提交产出开发预览。

## 首次启动

Brew 可以安装 ad-hoc 签名的 cask，但 macOS 可能阻止首次启动。先尝试打开应用，再在系统设置 → 隐私与安全点击“仍要打开”，由用户确认这个应用。更新后可能需要再次确认。流程不修改系统 Gatekeeper 设置或移除 quarantine。参考 [Apple 的说明](https://support.apple.com/en-us/102445)及 [Homebrew 的安全模型](https://docs.brew.sh/Homebrew-Security-and-Supply-Chain)。

## 名称

应用与包名为 HerdrX，Brew token 为 `herdrx`。当前处于早期开发，直接采用新的 bundle ID 与数据目录，不提供旧名称迁移层。

## 更新器验证

Debug 默认不启动更新器。隔离测试使用 `HERDRX_ENABLE_UPDATES=1`，可通过 `HERDRX_UPDATE_FEED_URL` 指定仅限 localhost/127.0.0.1 的 HTTP 测试源；Release 不接受这项覆盖。测试源仍必须通过内置公钥签名验证。测试构建使用独立 bundle ID、状态目录和命名 Herdr 会话；Sparkle 重启不会保留进程环境变量，因此 Debug 默认状态目录使用 `HerdrX Development`。

本轮实际验证了签名更新发现、手动安装重启、后台下载/退出安装、检查和下载取消、被篡改清单拒绝、已是最新版本。详见 [验证记录](app-updates/VALIDATION.md)。
