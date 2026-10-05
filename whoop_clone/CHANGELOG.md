# Changelog — Whoop Clone Project

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Phase 0: Repo Hygiene, Safety Net & CI Setup

### Added
- **GitHub Actions CI Workflow** (`.github/workflows/ci.yml`):
  - Automated continuous integration on `push` and `pull_request` targeting `main`.
  - Configured Java 17 and Flutter stable environments.
  - Automated `flutter pub get`, `flutter analyze`, and `flutter test` in `whoop_clone`.
- **Repository Hygiene & Directory Organization**:
  - Created `tools/` directory for auxiliary testing scripts (`test_*.py`, `embed_logos.py`) and prototype mockups (`whoop_app_mobile.html`).
  - Created `tools/build/` directory for automated APK build helpers (`BUILD_APK.bat`, `build_apk_quick.ps1`) with relative path resolution.
  - Created `docs/pdf/` directory consolidating technical PDFs and functional roadmaps.
  - Created `whoop_clone/assets/logos/neutral/` with non-proprietary placeholder assets (PNG and SVG format) to safeguard against trademark infringement in open distribution.
  - Added `whoop_clone/assets/logos/README.md` clarifying asset usage and branding separation.
- **Defect Catalog & Forensic Registry**:
  - Expanded `docs/KNOWN_ISSUES.md` and `whoop_clone/docs/KNOWN_ISSUES.md` with complete 54-issue catalog across all subsystems:
    - BLE Connection: `BLE-01` .. `BLE-08`
    - Protocol & Parser: `PRO-01` .. `PRO-04`
    - Ingestion & Database: `DAT-01` .. `DAT-08`
    - Sleep Detection: `SLP-01` .. `SLP-08`
    - Sleep Staging: `STG-01` .. `STG-07`
    - Fake Data & Provenance: `MCK-01` .. `MCK-03`, `TIM-01`
    - Background Service & OS: `BGD-01` .. `BGD-04`
    - Charts & Visualizations: `CHT-01` .. `CHT-04`
    - Quality & Testing: `QA-01` .. `QA-05`
    - Repository Hygiene: `REP-01` .. `REP-02`

### Changed
- Comprehensive `.gitignore` configured at root and `whoop_clone/.gitignore` to strictly exclude:
  - `android/local.properties` (personal local SDK paths)
  - `android/.gradle/` (Gradle cache and execution history)
  - `__pycache__/` and Python bytecode
  - Video (`*.mp4`) and archive (`*.zip`) binaries
  - Build outputs (`build/`, `*.apk`, `*.aab`)

### Removed
- Removed tracked binaries from git cache (`git rm --cached`):
  - `whoop_clone/android/local.properties`
  - All Gradle cache files under `whoop_clone/android/.gradle/`
  - Root zip archive `full_video_frames-20260806T124652Z-1-001.zip`
  - WhatsApp demonstration video `WhatsApp Video 2026-06-17 at 16.35.17.mp4`
  - `__pycache__` compiled bytecode files
  - Stray root `WHOOP Logo White.png` duplicate
