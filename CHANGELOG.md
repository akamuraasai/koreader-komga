# Changelog

Format based on [Keep a Changelog](https://keepachangelog.com/).
Versioning: **CalVer** (`YYYY.MM.DD`).

## [Unreleased]

## [2026.06.22] - 2026-06-22

First public release.

### Added
- Connect to a Komga server with a base URL and API key, configured from
  **Komga → Settings** inside KOReader.
- Home hub with six ways to browse the library: **Reading** (books in progress),
  **Deck** (on deck), **Last Updated**, **Last Added Series**, **Collections**,
  and **All** (search the whole library by title).
- Series browser with a multi-select chapter picker: pick any combination of
  chapters and bulk-download them in one action.
- Downloads saved into per-series folders, so each series stays self-contained on
  the device.
- Reading progress syncs back to Komga through KOReader's own sync, no extra setup.
- UI strings reuse KOReader's existing translation catalog, so the plugin inherits
  KOReader's translations in every language it already supports (no catalog shipped).
- CalVer versioning with the source of truth in `_meta.lua`.
- Tag-based release pipeline that builds the installable `komga.koplugin/` zip and
  publishes the GitHub Release, gated on the full KOReader-frontend e2e suite.
