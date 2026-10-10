# HerdrX icon

User-supplied artwork: a purple diagonal slash on a white rounded tile, adopted for HerdrX 0.1.5. The original image is preserved unchanged in Artwork.png. Xcode's Icon Composer source is App/AppIcon.icon; Apple’s compiler supplies native masks, presentation variants and a backwards-compatible ICNS.

The .icon input is resized to 1024 × 1024. Its layer uses a 1.225 scale to fit the supplied tile to the native icon mask, excluding the original image's outer presentation margin. No additional group shadow is applied. Preview.png is exported through Apple's ictool. scripts/icon.sh builds a complete 16–1024 pixel ICNS from that native rendition for macOS 14/15, while Assets.car supplies the native appearance on current macOS.

Prompt.txt records the provenance of the replacement artwork; no image generation was used for this version.
