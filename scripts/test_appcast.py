import base64
import hashlib
import pathlib
import tempfile
import unittest
from appcast import validate


class AppcastTests(unittest.TestCase):
    def test_release_contract_and_rejections(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = pathlib.Path(directory) / "HerdrX-1.2.3-universal.zip"
            archive.write_bytes(b"fixture archive")
            key = base64.b64encode(b"k" * 32).decode()
            signature = base64.b64encode(b"s" * 64).decode()
            info = dict(SUPublicEDKey=key, SURequireSignedFeed=True, SUVerifyUpdateBeforeExtraction=True, CFBundleVersion="42")
            metadata = dict(version="1.2.3", min_macos="14.0", filename=archive.name, sha256=hashlib.sha256(archive.read_bytes()).hexdigest())
            feed = f'''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>
                <sparkle:version>42</sparkle:version><sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>
                <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
                <enclosure url="https://github.com/cleanwk/herdrX/releases/download/v1.2.3/{archive.name}"
                length="{archive.stat().st_size}" sparkle:edSignature="{signature}"/></item></channel></rss>'''
            self.assertEqual(validate(feed, metadata, info, archive, key), signature)
            for old, new in [('>42<', '>41<'), ('>14.0<', '>13.0<'), ('github.com', 'example.org'), (signature, '')]:
                with self.subTest(old=old), self.assertRaises(ValueError):
                    validate(feed.replace(old, new), metadata, info, archive, key)
            with self.assertRaises(ValueError): validate(feed, metadata, {**info, 'SUPublicEDKey': ''}, archive, key)
            with self.assertRaises(ValueError): validate(feed, metadata, {**info, 'SURequireSignedFeed': False}, archive, key)
            archive.write_bytes(b'tampered fixture')
            with self.assertRaises(ValueError): validate(feed, metadata, info, archive, key)


if __name__ == "__main__": unittest.main()
