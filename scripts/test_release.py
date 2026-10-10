import importlib.util
import pathlib
import unittest

spec = importlib.util.spec_from_file_location("tap", pathlib.Path(__file__).parents[1] / "distribution/tap/update.py")
tap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tap)

class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.metadata = dict(version="1.2.3", filename="HerdrX-1.2.3-universal.zip", notarized=True,
                             architectures=["arm64", "x86_64"], min_macos="14.0", sha256="a" * 64)
        self.release = dict(tag_name="v1.2.3", draft=False, prerelease=False, assets=[dict(
            name=self.metadata["filename"], digest="sha256:" + self.metadata["sha256"],
            browser_download_url="https://github.com/cleanwk/herdrX/releases/download/v1.2.3/HerdrX-1.2.3-universal.zip")])
    def test_valid_release(self):
        text = tap.cask(self.release, self.metadata)
        self.assertIn('version "1.2.3"', text)
        self.assertIn('app "HerdrX.app"', text)
        self.assertNotIn("auto_updates", text)
    def test_ad_hoc_release(self):
        self.metadata["notarized"] = False
        text = tap.cask(self.release, self.metadata)
        self.assertIn("not notarized", text)
        self.assertIn("Open Anyway", text)
        self.assertNotIn("xattr", text)
        self.assertNotIn("spctl", text)
    def test_self_updating_release_requires_matching_feed(self):
        self.metadata.update(signed_updates=True, appcast_sha256="c" * 64)
        with self.assertRaises(ValueError): tap.cask(self.release, self.metadata)
        self.release["assets"].append(dict(name="appcast.xml", digest="sha256:" + "c" * 64,
            browser_download_url="https://github.com/cleanwk/herdrX/releases/download/v1.2.3/appcast.xml"))
        self.assertIn("auto_updates true", tap.cask(self.release, self.metadata))
        self.release["assets"][-1]["digest"] = "sha256:" + "d" * 64
        with self.assertRaises(ValueError): tap.cask(self.release, self.metadata)
    def test_reject_incomplete_and_mismatched_releases(self):
        for field, bad in [("notarized", "false"), ("sha256", "b" * 64), ("version", "1.2.4"), ("architectures", ["arm64"])]:
            with self.subTest(field=field):
                metadata = dict(self.metadata); metadata[field] = bad
                with self.assertRaises(ValueError): tap.cask(self.release, metadata)
    def test_reject_preview_and_injected_tag(self):
        for tag in ['v1.2.3-beta', 'v1.2.3";system("bad")', 'v1.2']:
            release = dict(self.release); release["tag_name"] = tag
            with self.assertRaises(ValueError): tap.cask(release, self.metadata)
        self.release["prerelease"] = True
        with self.assertRaises(ValueError): tap.cask(self.release, self.metadata)

if __name__ == "__main__": unittest.main()
