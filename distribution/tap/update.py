#!/usr/bin/env python3
"""Sync a verified, stable HerdrX release into the existing cleanwk tap."""
import json
import pathlib
import re
import subprocess

REPO = "cleanwk/herdrX"

def cask(release, metadata):
    tag = release["tag_name"]
    if release.get("draft") or release.get("prerelease") or not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Only stable versioned releases are supported")
    version = tag[1:]
    filename = f"HerdrX-{version}-universal.zip"
    if metadata.get("version") != version or metadata.get("filename") != filename:
        raise ValueError("Release version or asset filename mismatch")
    if type(metadata.get("notarized")) is not bool or set(metadata.get("architectures", [])) != {"arm64", "x86_64"}:
        raise ValueError("Universal release with explicit notarization status required")
    if metadata.get("min_macos") != "14.0":
        raise ValueError("Review cask minimum macOS before publishing")
    digest = metadata.get("sha256", "")
    if not re.fullmatch(r"[a-f0-9]{64}", digest):
        raise ValueError("Invalid SHA-256")
    assets = [a for a in release["assets"] if a["name"] == filename]
    if len(assets) != 1 or assets[0].get("digest") != "sha256:" + digest:
        raise ValueError("GitHub asset digest differs from release metadata")
    expected = f"https://github.com/{REPO}/releases/download/{tag}/{filename}"
    if assets[0].get("browser_download_url") != expected:
        raise ValueError("Unexpected download origin")
    notice = "" if metadata["notarized"] else '''
  caveats <<~EOS
    HerdrX uses ad-hoc signing and is not notarized by Apple.
    If macOS blocks the first launch, use System Settings > Privacy & Security > Open Anyway.
  EOS
'''
    return f'''cask "herdrx" do
  version "{version}"
  sha256 "{digest}"

  url "https://github.com/cleanwk/herdrX/releases/download/v#{{version}}/HerdrX-#{{version}}-universal.zip"
  name "HerdrX"
  desc "Native macOS workspace for Herdr terminals and coding agents"
  homepage "https://github.com/cleanwk/herdrX"

  depends_on macos: :sonoma
  app "HerdrX.app"

{notice}
  zap trash: "~/Library/Application Support/Herd-X"
end
'''

def gh(*args):
    return subprocess.run(["gh", *args], check=True, capture_output=True).stdout

def main():
    response = subprocess.run(["gh", "api", f"repos/{REPO}/releases/latest"], capture_output=True)
    if response.returncode:
        if b"404" in response.stderr or b"404" in response.stdout:
            print("No stable release yet; cask will appear after the first verified release.")
            return
        raise RuntimeError(response.stderr.decode())
    release = json.loads(response.stdout)
    target = pathlib.Path("Casks/herdrx.rb")
    current = target.read_text() if target.exists() else ""
    tag = release["tag_name"]
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Invalid version tag")
    match = re.search(r'version "(\d+\.\d+\.\d+)"', current)
    if match and tuple(map(int, match[1].split("."))) >= tuple(map(int, tag[1:].split("."))):
        print("Cask is current; no change.")
        return
    metadata_assets = [a for a in release["assets"] if a["name"] == "release.json"]
    if len(metadata_assets) != 1:
        raise ValueError("Missing release metadata")
    metadata = json.loads(gh("api", "-H", "Accept: application/octet-stream", f'repos/{REPO}/releases/assets/{metadata_assets[0]["id"]}'))
    content = cask(release, metadata)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    print(f"Updated herdrx to {tag}")

if __name__ == "__main__":
    main()
