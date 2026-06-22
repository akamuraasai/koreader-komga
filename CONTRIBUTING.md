# Contributing

Two tiers of automated tests (see the `Makefile`).

## Tier 1 — unit tests (fast, no KOReader)

Pure modules run under [busted](https://lujjjh.github.io/busted/):

```bash
make test     # alias for: busted
```

Tests cover:

- `pathutil` — path sanitization for FAT32.
- `komga_parse` — parsing API responses and series-title fallback.
- `selection` — chapter selection logic (unread, next N unread).
- `komga_api` — HTTP request building, mocking, and pagination edge cases.
- `chapter_row` — row text and status-glyph formatting.
- `paging` — page-preservation math.
- `download_path` / `download_plan` — on-disk paths and collision disambiguation.
- `download_dir` — download-root resolution fallback chain.

## Tier 2 — UI integration tests (real KOReader frontend)

`make test-integration` drives the *actual* KOReader widgets (Menu, ButtonDialog, …)
headlessly via KOReader's `kodev test front`, so the UI modules (`chapter_picker`, the
browsers, `downloader`) are tested for real — rendering rows, toggling selection on tap, the
select-unread → download flow, and the settings dialog (`spec/integration/komga_spec.lua`).

It needs a built KOReader checkout:

```bash
# one-time (see koreader/doc/Building.md):
git clone https://github.com/koreader/koreader.git ../koreader
cd ../koreader && ./kodev fetch-thirdparty && ./kodev build
```

> **macOS note:** the build downloads third-party sources with `wget`, which the official
> dependency list omits — run `brew install wget` if the build fails on a missing `wget`.

Then, from this repo:

```bash
make test-integration KOREADER_HOME=../koreader   # symlinks the plugin + spec, runs kodev
make unlink-integration KOREADER_HOME=../koreader  # remove the symlinks afterwards
```

The spec forces the `C` locale so assertions don't depend on the system language. A final
visual check in the emulator (`./kodev run`) or on-device is still worthwhile for layout.

## Linting

Static analysis runs with [luacheck](https://luacheck.readthedocs.io/) (config in
`.luacheckrc`):

```bash
make lint     # alias for: luacheck src spec
```

KOReader runs under LuaJIT, so lint in a Lua 5.1–5.4 or LuaJIT environment. (On macOS with
Homebrew Lua 5.5, luacheck 1.2.0 crashes; install it under LuaJIT and run
`make lint LUACHECK=$HOME/.luarocks/bin/luacheck`.)

## Code structure

Everything under `src/` (packaged as `komga.koplugin/` in releases):

- `main.lua` — entry point, menu registration, settings dialog.
- `_meta.lua` — plugin metadata + `version` (CalVer).

**`api/`** — Komga server connection:

- `komga_api.lua` — HTTP client for Komga API calls.
- `komga_parse.lua` — response parsing + URL building + title fallback (pure).

**`views/`** — UI (KOReader widgets):

- `home_browser.lua` — home hub (six browsing modes).
- `series_browser.lua` — series list with search.
- `collections_browser.lua` — collections list → scoped series.
- `chapter_picker.lua` — chapter selection with actions popup in the title bar.
- `chapter_row.lua` — row text + status glyphs (pure).
- `ui_util.lua` — fullscreen Menu factory + Trapper load/error wrapper.

**`domain/`** — business logic:

- `selection.lua` — unread/next-N selection logic (pure).
- `paging.lua` — page-preservation math (pure).
- `download_plan.lua` — unique destination per book, disambiguating collisions (pure).
- `download_path.lua` — on-disk path for a chapter (pure).
- `downloader.lua` — batch download + progress reporting.
- `chapter_name.lua` — zero-padded `.cbz` name from sort order (pure).

**`common/`** — helpers:

- `pathutil.lua` — FAT32-safe path sanitization (pure).
- `download_dir.lua` — download-root fallback chain (pure).
- `settings.lua` — credential and download-directory storage.

## Releasing

**CalVer** versioning (`YYYY.MM.DD`; `.N` suffix for two or more releases on the same day).
The version source of truth is `version` in `src/_meta.lua`.

1. Record changes in `CHANGELOG.md` under `## [Unreleased]`.
2. Cut the release (stamps the changelog, bumps `_meta.lua`, commits, and creates the tag):
   ```bash
   make release                       # uses today's date
   make release VERSION=2026.06.22     # explicit version
   ```
   Preview without changing anything with `DRY_RUN=1 ./scripts/release.sh`.
3. Push the tag — this triggers `.github/workflows/release.yml`:
   ```bash
   git push origin main vYYYY.MM.DD
   ```
4. The workflow runs the e2e integration suite as a **gate** (a tag whose e2e is red will not
   publish), then validates the tag matches `_meta.lua`, builds
   `komga.koplugin-vYYYY.MM.DD.zip`, and publishes the GitHub Release with notes (the
   CHANGELOG section + commit list). Tags with a `-rc`/`-beta` suffix are published as
   *pre-release*.
