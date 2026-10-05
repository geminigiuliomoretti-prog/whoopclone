# Assets & Brand Management — Whoop Clone

## Directory Structure

```
assets/logos/
├── README.md                          # Brand & licensing instructions (this file)
├── neutral/                           # Open-source non-proprietary placeholder assets
│   ├── neutral_circle_white.png
│   ├── neutral_circle_black.png
│   ├── neutral_logo_white.png
│   ├── neutral_logo_black.png
│   ├── neutral_circle_white.svg
│   └── neutral_circle_black.svg
├── whoop_circle_white.png             # Local research/development reference asset
├── whoop_logo_white.png
├── whoop_logo_black.png
└── whoop_puck_white.png
```

## Legal & Trademark Notice

1. **Trademark Notice:** "WHOOP" and associated wordmarks, logos, and emblems are registered trademarks of Whoop, Inc.
2. **Open Source & Redistribution:** When distributing binaries publicly, publishing to application stores (e.g. Google Play Store / Apple App Store), or making the repository public, proprietary assets in `assets/logos/` should be substituted with the non-proprietary placeholder assets located in `assets/logos/neutral/`.
3. **Graceful Fallbacks:** The UI components in Flutter (such as `MainNavigationScreen`) feature vector/text error fallbacks (`\V/` or biometric pulse waveforms) that render automatically if image assets are stripped or omitted.
