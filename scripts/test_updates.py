import copy
import hashlib
import json
import pathlib
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import updates


class UpdateHistoryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.info = dict(CFBundleIdentifier="app.herdrx", CFBundleVersion="42",
                         CFBundleShortVersionString="1.2.3", SUPublicEDKey="test-public-key")
        self.old_info = dict(self.info, CFBundleVersion="41", CFBundleShortVersionString="1.2.2")
        self.archive = self.directory / "HerdrX-1.2.2-universal.zip"
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("HerdrX.app/Contents/Info.plist", plistlib.dumps(self.old_info))
        self.metadata = dict(version="1.2.2", build="41", filename=self.archive.name,
                             architectures=["arm64", "x86_64"], sha256=self.digest(self.archive))
        (self.directory / "release.json").write_text(json.dumps(self.metadata))
        self.release = dict(tag_name="v1.2.2", assets=[])
        self.refresh_assets()

    @staticmethod
    def digest(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def refresh_assets(self):
        self.release["assets"] = [dict(name=path.name, size=path.stat().st_size,
            digest="sha256:" + self.digest(path), browser_download_url=
            f"https://github.com/cleanwk/herdrX/releases/download/v1.2.2/{path.name}")
            for path in (self.archive, self.directory / "release.json")]

    def test_select_three_preceding_stable_versions_numerically(self):
        releases = [dict(tag_name=tag) for tag in ["v1.2.9", "v1.2.10", "v1.2.8", "v1.2.7",
                                                  "v2.0.0", "v1.2.11", "v1.2.11-rc", "invalid"]]
        releases += [dict(tag_name="v1.2.10", draft=True), dict(tag_name="v1.2.10", prerelease=True)]
        self.assertEqual([r["tag_name"] for r in updates.previous_releases(releases, "1.2.11")],
                         ["v1.2.10", "v1.2.9", "v1.2.8"])
        self.assertEqual(updates.previous_releases(releases, "0.1.0"), [])

    def test_exact_published_archive_is_accepted(self):
        self.assertEqual(updates.validate_history(self.release, self.directory, self.info), self.archive)

    def test_reject_asset_digest_size_origin_and_duplicates(self):
        for field, value in [("digest", "sha256:" + "0" * 64), ("size", 1),
                             ("browser_download_url", "https://example.org/archive.zip")]:
            release = copy.deepcopy(self.release)
            release["assets"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                updates.validate_history(release, self.directory, self.info)
        self.release["assets"].append(self.release["assets"][0])
        with self.assertRaises(ValueError): updates.validate_history(self.release, self.directory, self.info)

    def test_reject_changed_identity_key_or_nonpreceding_build(self):
        for field, value in [("CFBundleIdentifier", "wrong.app"), ("SUPublicEDKey", "different-key"),
                             ("CFBundleVersion", "41")]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                updates.validate_history(self.release, self.directory, dict(self.info, **{field: value}))

    def test_reject_metadata_even_when_github_digest_matches(self):
        for field, value in [("sha256", "0" * 64), ("build", "40"), ("version", "1.2.1"),
                             ("filename", "../other.zip"), ("architectures", ["arm64"])]:
            (self.directory / "release.json").write_text(json.dumps(dict(self.metadata, **{field: value})))
            self.refresh_assets()
            with self.subTest(field=field), self.assertRaises(ValueError):
                updates.validate_history(self.release, self.directory, self.info)

    @patch("updates.subprocess.run")
    def test_list_failure_and_empty_history_allow_full_update(self, run):
        run.side_effect = subprocess.CalledProcessError(1, "gh")
        self.assertEqual(updates.fetch_history(self.directory, self.info), [])
        run.side_effect = None
        run.return_value = subprocess.CompletedProcess([], 0, stdout=b"[]")
        self.assertEqual(updates.fetch_history(self.directory, self.info), [])

    @patch("updates.validate_history")
    @patch("updates.subprocess.run")
    def test_failed_download_does_not_discard_other_bases(self, run, validate):
        run.side_effect = [subprocess.CompletedProcess([], 0, stdout=json.dumps([
            dict(tag_name="v1.2.2"), dict(tag_name="v1.2.1")])),
            subprocess.TimeoutExpired("gh", 180), subprocess.CompletedProcess([], 0)]
        validate.return_value = self.archive
        self.assertEqual(updates.fetch_history(self.directory, self.info), [self.archive])
        self.assertEqual(validate.call_count, 1)


if __name__ == "__main__": unittest.main()
