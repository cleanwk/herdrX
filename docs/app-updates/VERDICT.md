disposition: ship

Verdict pass, 2026-10-10. Scope: the single cancellation-state material fix from [FINISH-REVIEW.md](FINISH-REVIEW.md). The reviewer scored that fix resolved. This is not a new whole-surface audit or approval of release publication. No web detector was run for this native macOS implementation.

## persistence

The initial review remains as a historical record and links here. The mandated documenter refresh is still pending at this verdict: update the product/design records to describe the new updater and its actual evidence. This verdict does not claim those documents were already refreshed.

## fidelity

| Material fix | Score | Evidence |
| --- | --- | --- |
| Clear canceled manual-check and canceled-download progress, preserving retry | resolved | `App/Updater.swift` now handles `userDidCancelDownload`, clears progress and failure, and sets the canceled message. A nil-error finish while `checking` remains true handles initial-check cancellation. Both [check-canceled.png](evidence/check-canceled.png) and [download-canceled.png](evidence/download-canceled.png) were opened: each is a complete, valid 840 × 996 native About capture with “更新已取消，可稍后重试。”, no spinner and a visible retry button. Their [check AX](evidence/check-canceled-ax.txt) and [download AX](evidence/download-canceled-ax.txt) records report enabled “检查更新…” and “查看并安装更新…” buttons respectively. |

The additional [automatic-ready capture](evidence/automatic-ready.png) and [AX record](evidence/automatic-ready-ax.txt) show both automatic options enabled and “更新已就绪，将在退出 HerdrX 时安装。” with the manual action still available. This supports preservation of the legitimate ready-on-quit state. The parent reports that the download was initiated automatically, without a manual check.

## ceiling

All four supplied new PNGs were opened and are valid. The cancellation and automatic-ready captures are legible without overflow. [invalid-signature.png](evidence/invalid-signature.png) shows the native Sparkle alert explicitly rejecting the improperly signed feed; [update-failed-ax.txt](evidence/update-failed-ax.txt) records the matching retryable About failure and enabled action. This is evidence of rejection by the running fixture client, beyond the earlier command-line signature check.

[install-result.json](evidence/install-result.json) records a fixture upgrade from 0.1.7 (9) to 0.1.8 (10), passing manual install/relaunch, background download/install on quit, deep signature verification, and preserved persistent session content/SGR. These are the implementation thread's recorded results; this reviewer read them but did not repeat installation or code-signature verification. They do not establish a published release, Apple notarization, every supported macOS version, English layout, VoiceOver or full keyboard traversal. The no-update runtime branch was still being captured when this verdict was issued.

## material_fixes

The one listed material fix is resolved. No partial or unresolved item remains in this verdict's fix list. No new defect hunt or redesign was performed in this pass.

## keep

Keep the cancellation callbacks, enabled retry paths, ready-on-quit state, automatic-download opt-in, native Sparkle installer and explicit signed-feed failure. Retain the existing evidence boundaries and complete the planned documentation handoff.
