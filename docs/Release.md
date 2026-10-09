# Release

主分发使用已有的 `cleanwk/homebrew-tap`。应用仓库负责产出可信 ZIP，tap 自己读取稳定 Release、验证资产摘要后更新 cask，无需跨仓库写权限的个人 token。

## 一次配置

在 `cleanwk/herdrX` 的 GitHub Settings 中配置 `release` environment。需要有效的 **Developer ID Application** 证书；Apple Development 证书不能替代它。

| 类型 | 名称 | 内容 |
| --- | --- | --- |
| Secret | `MACOS_CERTIFICATE_P12` | 包含私钥的 Developer ID Application PKCS#12 文件，以 base64 编码 |
| Secret | `MACOS_CERTIFICATE_PASSWORD` | P12 导出密码 |
| Variable | `MACOS_SIGN_IDENTITY` | `Developer ID Application: … (TEAMID)` 的完整身份名称 |
| Secret | `APPLE_ID` | 用于 Apple 公证的账户 |
| Variable | `APPLE_TEAM_ID` | Apple Developer Team ID |
| Secret | `APPLE_APP_PASSWORD` | Apple app-specific password |
| Variable，可选 | `SPARKLE_PUBLIC_KEY` | 稳定的 Sparkle Ed25519 公钥 |
| Secret，可选 | `SPARKLE_PRIVATE_KEY` | 对应的 Sparkle 私钥文本 |

凭据通过 GitHub Secrets 配置，不写进仓库。Sparkle 两个值必须一起配置；Brew 安装由 Brew 升级，直接下载才启用 Sparkle。当前任务开始时这些发布配置为空，本机没有 Developer ID Application 身份，因此没有发布未经公证的正式版本。

## 每个版本

1. 更新 `VERSION`，使用 `major.minor.patch`，提交修改。
2. 确认 CI 成功，推送与 VERSION 一致的 `vmajor.minor.patch` tag。
3. Release Action 构建 universal app、验证两种架构与签名、提交 Apple 公证并 staple；成功后上传 ZIP、SHA256SUMS、release.json 和可选 appcast.xml。
4. 已有 tap 的更新 Action 每 15 分钟检查一次，或手动 Run workflow。它只接受稳定、经过公证、架构完整且 GitHub 资产 digest 与元数据一致的版本，禁止降级，然后提交真实 cask。
5. 用户运行 `brew update && brew upgrade --cask herd-x`。

`distribution/tap/update.py` 和 `herd-x.yml` 是需要放进既有 tap 的文件，分别放到 `scripts/update-herd-x.py` 与 `.github/workflows/herd-x.yml`。首次稳定版本之前不生成占位 cask，也不填虚构校验值。计划任务要求工作流在 tap 默认分支上。tap 应用自己的 GITHUB_TOKEN 写入自身仓库。

## 本地验证

`scripts/build.sh` 默认生成 ad-hoc universal app，`scripts/package.sh` 输出开发预览及 `notarized: false` 元数据。这种产物不会通过 tap 的正式更新门槛。Ad-hoc 预览关闭 hardened runtime，以便加载没有 Developer ID team 的 Sparkle；正式签名构建启用 hardened runtime，并校验应用与 Sparkle 的签名 team 一致。

正式本地构建可设置 `SIGN_IDENTITY`，打包时设置 `NOTARIZE=1`、`APPLE_ID`、`APPLE_TEAM_ID` 和 `APPLE_APP_PASSWORD`。仅在公证 Accepted、staple 和 spctl 检查成功后写入 `notarized: true`。

CI runner 使用 GitHub 当前公布的 [xcode-27](https://github.com/actions/runner-images/blob/main/README.md)，构建工具固定在 Xcode 27 系列。流程不会在每次普通代码提交时发布用户版本；每个正式版本 tag 触发一次发布，PR 和默认分支提交产出开发预览。
